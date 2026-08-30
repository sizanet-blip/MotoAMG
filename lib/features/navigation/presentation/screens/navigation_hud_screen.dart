import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/gps_status.dart';
import 'package:loc_motos/core/utils/navigation_bearing.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/groups/data/repositories/group_pack_alert_repository.dart';
import 'package:loc_motos/features/groups/domain/entities/group_incident.dart';
import 'package:loc_motos/features/groups/domain/entities/group_member.dart';
import 'package:loc_motos/features/groups/domain/entities/ride_role.dart';
import 'package:loc_motos/features/groups/domain/services/group_pack_proximity_tracker.dart';
import 'package:loc_motos/features/groups/domain/services/group_ride_alert_feedback.dart';
import 'package:loc_motos/features/groups/presentation/providers/group_providers.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_incident_session_panel.dart';
import 'package:loc_motos/features/groups/presentation/widgets/group_pack_list_sheet.dart';
import 'package:loc_motos/features/intercom/presentation/widgets/intercom_controls_bar.dart';
import 'package:loc_motos/features/intercom/presentation/widgets/intercom_session_binder.dart';
import 'package:loc_motos/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:loc_motos/features/navigation/data/services/route_alerts_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_progress_simulator.dart';
import 'package:loc_motos/features/navigation/domain/entities/alert_preferences.dart';
import 'package:loc_motos/features/navigation/domain/entities/fuel_alert_display.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/theme/fuel_brand_style.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_lane_guidance_panel.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_maneuver_card.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_status_bar.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/group_live_location_publisher.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/own_position_watcher.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class NavigationHudScreen extends ConsumerStatefulWidget {
  const NavigationHudScreen({
    super.key,
    required this.route,
    required this.user,
    this.chaseCabecera = false,
    this.sharedGroupRoute,
    this.enableGroupFeatures = false,
  });

  final NavigationRoute route;
  final AppUser user;

  /// Rezagado: ir a la cabecera en vivo hasta enganchar el trazado del grupo.
  final bool chaseCabecera;

  /// Ruta compartida del pelotón (fase 2). Necesaria si [chaseCabecera].
  final NavigationRoute? sharedGroupRoute;

  /// Intercom, avisos de grupo y pelotón. Solo true al navegar desde el mapa del grupo.
  final bool enableGroupFeatures;

  @override
  ConsumerState<NavigationHudScreen> createState() =>
      _NavigationHudScreenState();
}

class _NavigationHudScreenState extends ConsumerState<NavigationHudScreen> {
  late NavigationRoute _route;
  var _maneuverIndex = 0;
  var _offRoute = false;

  /// Solo avisamos de desvío si ya estuviste alguna vez sobre la ruta.
  var _hasJoinedRoute = false;
  /// Metros hasta el próximo aviso (tarjeta superior).
  var _remainingMeters = 0.0;
  /// Metros hasta el destino a lo largo de la ruta (barra inferior).
  var _routeRemainingMeters = 0.0;
  Duration _remainingDuration = Duration.zero;
  int? _speedLimitKmh;
  RouteProgressSimulator? _simulator;
  Timer? _simulationTimer;
  Timer? _rerouteDebounceTimer;
  var _simulating = false;
  /// Velocidad del simulador (km/h); el deslizador la cambia en vivo.
  var _simulationSpeedKmh = NavigationConstants.simulationSpeedMps * 3.6;
  var _rerouting = false;
  String? _rerouteError;
  DateTime? _lastRerouteAt;
  var _arrived = false;
  RouteAlert? _upcomingAlert;
  double _upcomingAlertMeters = 0;
  RouteAlert? _upcomingFuel;
  double _upcomingFuelMeters = 0;
  final _packTracker = GroupPackProximityTracker();
  /// Motos del grupo en el HUD (se puede apagar con el botón).
  var _showGroupMates = true;
  var _userToggledGroupVisibility = false;
  RouteAlert? _upcomingToll;
  String? _lastSharedRouteFingerprint;
  double _upcomingTollMeters = 0;
  final _announcedAlertIds = <String>{};
  final _announcedManeuverIndices = <int>{};
  var _arrivalAnnounced = false;
  /// Si el usuario arrastra el mapa, deja de seguir el GPS hasta recentrar.
  var _cameraFollowUser = true;
  var _cameraFollowEpoch = 0;
  double? _savedBrightness;
  var _hudDisplayArmed = false;
  final _bearingFilter = NavigationBearingFilter();
  NavigationRoute? _sharedGroupRoute;
  var _chasingCabecera = false;
  var _joiningSharedRoute = false;
  Timer? _cabeceraChaseTimer;
  GeoPoint? _lastChaseTarget;

  bool get _showSimulatorControls =>
      ref.watch(hudSafetyProvider).showRouteSimulator && !_arrived;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _sharedGroupRoute = widget.sharedGroupRoute;
    _chasingCabecera =
        widget.chaseCabecera && widget.sharedGroupRoute != null;
    if (_chasingCabecera) {
      _lastChaseTarget = widget.route.destination;
    }
    // Evitar arrastrar coordenadas de una simulación anterior.
    try {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
      _showGroupMates =
          ref.read(groupPackAlertProvider).showGroupOnNavigation;
    } catch (_) {}
    _bootstrapGuidance(_route);
    if (_chasingCabecera) {
      _cabeceraChaseTimer = Timer.periodic(
        NavigationConstants.cabeceraChaseRefresh,
        (_) => unawaited(_refreshCabeceraChase()),
      );
    }
    if (!_route.hasAlerts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_enrichActiveRouteAlerts());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSpeedLimits());
      unawaited(_armHudDisplay());
      unawaited(_syncGuidanceToMyGps());
    });
  }

  /// Arranca la guía desde tu GPS, no desde el origen de quien publicó la ruta.
  Future<void> _syncGuidanceToMyGps() async {
    await _restoreRealGpsPosition(updateGuidance: false);
    if (!mounted || _arrived || _simulating) {
      return;
    }
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    final position = GeoPoint(lat: own.lat, lng: own.lng);
    final deviation = ref.read(routeDeviationServiceProvider);
    final distanceToRoute = deviation.distanceToPolylineMeters(
      position,
      _route.polyline,
    );
    if (distanceToRoute > NavigationConstants.deviationThresholdMeters &&
        _hasNetwork()) {
      await _rerouteIfNeeded(force: true);
      return;
    }
    _updateGuidance();
    final maneuver = _currentManeuver;
    if (maneuver == null) {
      return;
    }
    _maybeAnnounceManeuver(
      maneuver,
      remainingMeters: _remainingMeters,
      force: true,
    );
  }

  Future<void> _armHudDisplay() async {
    if (_hudDisplayArmed) {
      return;
    }
    _hudDisplayArmed = true;
    final safety = ref.read(hudSafetyProvider);
    try {
      if (safety.keepScreenOn) {
        await WakelockPlus.enable();
      }
      if (safety.highBrightness) {
        _savedBrightness = await ScreenBrightness.instance.application;
        await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      }
    } catch (_) {}
  }

  Future<void> _disarmHudDisplay() async {
    if (!_hudDisplayArmed) {
      return;
    }
    _hudDisplayArmed = false;
    try {
      // Si sigues en el mapa de grupo, LocationBinder mantiene la pantalla.
      final keepForGroup = ref.read(groupMapSessionOpenProvider) &&
          ref.read(hudSafetyProvider).keepScreenOn;
      if (!keepForGroup) {
        await WakelockPlus.disable();
      }
      final saved = _savedBrightness;
      if (saved != null) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(saved);
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (_) {}
    _savedBrightness = null;
  }

  void _bootstrapGuidance(NavigationRoute route) {
    final guidance = RouteGuidanceService();
    final own = ref.read(ownDevicePositionProvider);
    final position = own == null
        ? route.origin
        : GeoPoint(lat: own.lat, lng: own.lng);
    final maneuvers = route.maneuvers;
    if (maneuvers.length > 1) {
      _maneuverIndex = guidance.resolveUpcomingManeuverIndex(
        position: position,
        route: route,
      );
      _remainingMeters = guidance.remainingMetersToUpcoming(
        position: position,
        route: route,
        upcomingIndex: _maneuverIndex,
      );
    } else {
      _maneuverIndex = 0;
      _remainingMeters =
          maneuvers.firstOrNull?.distanceMeters ?? route.distanceMeters;
    }
    _routeRemainingMeters = guidance.remainingRouteMeters(
      position: position,
      route: route,
    );
    _remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: _routeRemainingMeters,
      speedMps: own?.speedMps ?? 0,
      routeDurationSeconds: route.durationSeconds,
      routeDistanceMeters: route.distanceMeters,
    );
    _speedLimitKmh = guidance.resolveSpeedLimitKmh(
      position: position,
      route: route,
    );
    if (route.hasAlerts) {
      final along = guidance.distanceAlongRouteMeters(
        position,
        route.polyline,
      );
      final prefs = ref.read(alertPreferencesProvider);
      _syncUpcomingFromAlong(
        route,
        along,
        prefs,
        position: position,
      );
    }
  }

  void _syncUpcomingFromAlong(
    NavigationRoute route,
    double along,
    AlertPreferences prefs, {
    GeoPoint? position,
  }) {
    final alerts = RouteAlertsService();
    final grace = NavigationConstants.alertPassedGraceMeters;

    if (prefs.radarsEnabled) {
      final next = alerts.nextRadar(
        route: route,
        alongMeters: along,
        graceMeters: grace,
        position: position,
      );
      final meters = next == null
          ? 0.0
          : (next.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      if (next != null && meters <= prefs.radarHudMeters) {
        _upcomingAlert = next;
        _upcomingAlertMeters = meters;
      } else {
        _upcomingAlert = null;
        _upcomingAlertMeters = 0;
      }
    } else {
      _upcomingAlert = null;
      _upcomingAlertMeters = 0;
    }

    if (prefs.fuelEnabled) {
      final fuel = alerts.nextFuel(
        route: route,
        alongMeters: along,
        graceMeters: grace,
      );
      final fuelMeters = fuel == null
          ? 0.0
          : (fuel.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      if (fuel != null && fuelMeters <= prefs.fuelAnnounceMeters) {
        _upcomingFuel = fuel;
        _upcomingFuelMeters = fuelMeters;
      } else {
        _upcomingFuel = null;
        _upcomingFuelMeters = 0;
      }
    } else {
      _upcomingFuel = null;
      _upcomingFuelMeters = 0;
    }

    if (prefs.tollsEnabled) {
      final toll = alerts.nextToll(
        route: route,
        alongMeters: along,
        graceMeters: grace,
      );
      final tollMeters = toll == null
          ? 0.0
          : (toll.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      if (toll != null && tollMeters <= prefs.tollAnnounceMeters) {
        _upcomingToll = toll;
        _upcomingTollMeters = tollMeters;
      } else {
        _upcomingToll = null;
        _upcomingTollMeters = 0;
      }
    } else {
      _upcomingToll = null;
      _upcomingTollMeters = 0;
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _rerouteDebounceTimer?.cancel();
    _rerouteDebounceTimer = null;
    _cabeceraChaseTimer?.cancel();
    _cabeceraChaseTimer = null;
    unawaited(_disarmHudDisplay());
    try {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
    } catch (_) {
      // Widget ya desmontado.
    }
    super.dispose();
  }

  /// Vuelve a escribir la posición GPS real (la simulación pisa [ownDevicePositionProvider]).
  Future<void> _restoreRealGpsPosition({bool updateGuidance = false}) async {
    try {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
      final position =
          await ref.read(deviceLocationServiceProvider).readPosition();
      if (position == null) {
        return;
      }
      ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading >= 0 ? position.heading : null,
        speedMps: position.speed >= 0 ? position.speed : 0,
        accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
      );
      if (mounted && updateGuidance && !_simulating) {
        _updateGuidance();
      }
    } catch (_) {
      // Sin GPS: el watcher volverá a escribir cuando haya fix.
    }
  }

  NavigationManeuver? get _currentManeuver =>
      _route.maneuvers.elementAtOrNull(_maneuverIndex);

  NavigationManeuver? get _nextManeuver =>
      _route.maneuvers.elementAtOrNull(_maneuverIndex + 1);

  void _updateGuidance() {
    if (_arrived) {
      return;
    }
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    final position = GeoPoint(lat: own.lat, lng: own.lng);
    final guidance = ref.read(routeGuidanceServiceProvider);
    final deviation = ref.read(routeDeviationServiceProvider);

    if (_chasingCabecera || _joiningSharedRoute) {
      if (_shouldJoinSharedGroupRoute(position)) {
        unawaited(_joinSharedGroupRoute());
        return;
      }
    } else if (_hasArrivedAtFinalDestination(position, guidance)) {
      _onArrived();
      return;
    }

    // En simulación siempre vas sobre el trazado.
    if (_simulating) {
      _rerouteDebounceTimer?.cancel();
      if (_offRoute || !_hasJoinedRoute) {
        setState(() {
          _offRoute = false;
          _hasJoinedRoute = true;
          _rerouteError = null;
        });
      }
    } else {
      final distanceToRoute = deviation.distanceToPolylineMeters(
        position,
        _route.polyline,
      );
      final onRoute =
          distanceToRoute <= NavigationConstants.deviationThresholdMeters;

      if (onRoute) {
        _rerouteDebounceTimer?.cancel();
        // Primera vez (o de nuevo) sobre la ruta: armar detección de desvío.
        if (!_hasJoinedRoute || _offRoute) {
          setState(() {
            _hasJoinedRoute = true;
            _offRoute = false;
            _rerouteError = null;
          });
        }
      } else if (_hasJoinedRoute) {
        // Solo “te has salido” si antes estabas en la ruta.
        if (!_offRoute) {
          setState(() => _offRoute = true);
          _scheduleReroute();
        }
      } else {
        // Origen/destino remotos: estás lejos, pero aún no “entraste” en la ruta.
        _rerouteDebounceTimer?.cancel();
        if (_offRoute) {
          setState(() => _offRoute = false);
        }
      }
    }

    final upcomingIndex = guidance.resolveUpcomingManeuverIndex(
      position: position,
      route: _route,
    );
    final remaining = guidance.remainingMetersToUpcoming(
      position: position,
      route: _route,
      upcomingIndex: upcomingIndex,
    );
    final routeRemaining = guidance.remainingRouteMeters(
      position: position,
      route: _route,
    );
    final remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: routeRemaining,
      speedMps: own.speedMps,
      routeDurationSeconds: _route.durationSeconds,
      routeDistanceMeters: _route.distanceMeters,
    );
    final speedLimit = guidance.resolveSpeedLimitKmh(
      position: position,
      route: _route,
    );
    final along = guidance.distanceAlongRouteMeters(position, _route.polyline);
    final alertsService = ref.read(routeAlertsServiceProvider);
    final prefs = ref.read(alertPreferencesProvider);
    final grace = NavigationConstants.alertPassedGraceMeters;

    RouteAlert? upcomingAlert;
    var upcomingAlertMeters = 0.0;
    if (prefs.radarsEnabled) {
      final nextRadar = alertsService.nextRadar(
        route: _route,
        alongMeters: along,
        graceMeters: grace,
        position: position,
      );
      final meters = nextRadar == null
          ? 0.0
          : (nextRadar.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      if (nextRadar != null && meters <= prefs.radarHudMeters) {
        upcomingAlert = nextRadar;
        upcomingAlertMeters = meters;
      }
    }

    RouteAlert? nextFuel;
    var nextFuelMeters = 0.0;
    var showFuel = false;
    if (prefs.fuelEnabled) {
      nextFuel = alertsService.nextFuel(
        route: _route,
        alongMeters: along,
        graceMeters: grace,
      );
      nextFuelMeters = nextFuel == null
          ? 0.0
          : (nextFuel.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      showFuel =
          nextFuel != null && nextFuelMeters <= prefs.fuelAnnounceMeters;
    }

    RouteAlert? nextToll;
    var nextTollMeters = 0.0;
    var showToll = false;
    if (prefs.tollsEnabled) {
      nextToll = alertsService.nextToll(
        route: _route,
        alongMeters: along,
        graceMeters: grace,
      );
      nextTollMeters = nextToll == null
          ? 0.0
          : (nextToll.distanceAlongRouteMeters - along).clamp(0.0, 1e9);
      showToll =
          nextToll != null && nextTollMeters <= prefs.tollAnnounceMeters;
    }

    final nextCurve = prefs.curvesEnabled && prefs.curvesVoiceEnabled
        ? alertsService.nextCurve(
            route: _route,
            alongMeters: along,
            graceMeters: grace,
          )
        : null;
    final nextCurveMeters = nextCurve == null
        ? 0.0
        : (nextCurve.distanceAlongRouteMeters - along).clamp(0.0, 1e9);

    final maneuverChanged = upcomingIndex != _maneuverIndex;
    final metersChanged = (remaining - _remainingMeters).abs() > 5;
    final routeMetersChanged =
        (routeRemaining - _routeRemainingMeters).abs() > 10;
    final durationChanged =
        (remainingDuration.inSeconds - _remainingDuration.inSeconds).abs() > 5;
    final limitChanged = speedLimit != _speedLimitKmh;
    final alertChanged = upcomingAlert?.id != _upcomingAlert?.id ||
        (upcomingAlertMeters - _upcomingAlertMeters).abs() > 10;
    final fuelChanged =
        (showFuel ? nextFuel!.id : null) != _upcomingFuel?.id ||
            (showFuel && (nextFuelMeters - _upcomingFuelMeters).abs() > 15);
    final tollChanged =
        (showToll ? nextToll!.id : null) != _upcomingToll?.id ||
            (showToll && (nextTollMeters - _upcomingTollMeters).abs() > 15);

    if (maneuverChanged ||
        metersChanged ||
        routeMetersChanged ||
        durationChanged ||
        limitChanged ||
        alertChanged ||
        fuelChanged ||
        tollChanged) {
      setState(() {
        _maneuverIndex = upcomingIndex;
        _remainingMeters = remaining;
        _routeRemainingMeters = routeRemaining;
        _remainingDuration = remainingDuration;
        _speedLimitKmh = speedLimit;
        _upcomingAlert = upcomingAlert;
        _upcomingAlertMeters = upcomingAlertMeters;
        _upcomingFuel = showFuel ? nextFuel : null;
        _upcomingFuelMeters = showFuel ? nextFuelMeters : 0;
        _upcomingToll = showToll ? nextToll : null;
        _upcomingTollMeters = showToll ? nextTollMeters : 0;
      });
    }
    final upcoming = _route.maneuvers.elementAtOrNull(upcomingIndex);
    if (upcoming != null) {
      _maybeAnnounceManeuver(upcoming, remainingMeters: remaining);
    }
    if (upcomingAlert != null) {
      _maybeAnnounceTypedAlert(
        upcomingAlert,
        upcomingAlertMeters,
        prefs: prefs,
      );
    }
    if (showFuel && nextFuel != null) {
      _maybeAnnounceTypedAlert(nextFuel, nextFuelMeters, prefs: prefs);
    }
    if (showToll && nextToll != null) {
      _maybeAnnounceTypedAlert(nextToll, nextTollMeters, prefs: prefs);
    }
    if (nextCurve != null &&
        nextCurveMeters <= prefs.announceMetersFor(RouteAlertType.sharpCurve)) {
      _maybeAnnounceTypedAlert(nextCurve, nextCurveMeters, prefs: prefs);
    }
  }

  void _maybeAnnounceTypedAlert(
    RouteAlert alert,
    double metersAhead, {
    required AlertPreferences prefs,
  }) {
    if (!prefs.voiceEnabledFor(alert.type)) {
      return;
    }
    final session = ref.read(navigationSessionProvider.notifier);

    if (alert.type == RouteAlertType.speedCamera) {
      final thresholds = prefs.radarThresholdsDescending;
      final strongest = prefs.radarImminentMeters;
      for (final threshold in thresholds) {
        if (metersAhead > threshold) {
          continue;
        }
        final key = '${alert.id}_at_${threshold.round()}';
        if (_announcedAlertIds.contains(key)) {
          continue;
        }
        _announcedAlertIds.add(key);
        final imminent = (threshold - strongest).abs() < 0.5;
        unawaited(
          session.announceManeuver(
            alert.announcementForDistance(
              metersAhead,
              imminent: imminent,
            ),
          ),
        );
        // Una sola voz por tick (la más lejana pendiente).
        break;
      }
      return;
    }

    final approachKey = '${alert.id}_approach';
    final announceAt = prefs.announceMetersFor(alert.type);
    if (metersAhead <= announceAt &&
        !_announcedAlertIds.contains(approachKey)) {
      _announcedAlertIds.add(approachKey);
      unawaited(
        session.announceManeuver(
          alert.announcementForDistance(metersAhead),
        ),
      );
    }
  }

  /// Anuncia giros al acercarse; la llegada final solo en [_onArrived].
  void _maybeAnnounceManeuver(
    NavigationManeuver maneuver, {
    required double remainingMeters,
    bool force = false,
  }) {
    if (_arrived || _announcedManeuverIndices.contains(maneuver.index)) {
      return;
    }
    final isFinalArrive = maneuver.type == ManeuverType.arrive &&
        maneuver.index >= _route.maneuvers.length - 1;
    if (isFinalArrive) {
      return;
    }
    final nearEnough =
        remainingMeters <= NavigationConstants.maneuverAnnounceMeters;
    if (!nearEnough && !force) {
      return;
    }
    _announcedManeuverIndices.add(maneuver.index);
    unawaited(
      ref
          .read(navigationSessionProvider.notifier)
          .announceManeuver(maneuver.spokenInstruction),
    );
  }

  /// Tras perseguir a la cabecera, el destino válido es el del pelotón, no ella.
  bool _hasArrivedAtFinalDestination(
    GeoPoint position,
    RouteGuidanceService guidance,
  ) {
    if (widget.chaseCabecera) {
      final shared = _sharedGroupRoute;
      if (shared == null) {
        return false;
      }
      return guidance.hasArrived(position: position, route: shared);
    }
    return guidance.hasArrived(position: position, route: _route);
  }

  void _onArrived() {
    if (_arrived || !mounted || _chasingCabecera || _joiningSharedRoute) {
      return;
    }
    if (widget.chaseCabecera) {
      final own = ref.read(ownDevicePositionProvider);
      if (own != null) {
        final position = GeoPoint(lat: own.lat, lng: own.lng);
        final guidance = ref.read(routeGuidanceServiceProvider);
        if (!_hasArrivedAtFinalDestination(position, guidance)) {
          return;
        }
      }
    }
    _rerouteDebounceTimer?.cancel();
    _stopSimulation(keepLastPosition: true);
    setState(() {
      _arrived = true;
      _offRoute = false;
      _rerouting = false;
      _rerouteError = null;
      _remainingMeters = 0;
      _routeRemainingMeters = 0;
      _remainingDuration = Duration.zero;
    });
    if (!_arrivalAnnounced) {
      _arrivalAnnounced = true;
      unawaited(
        ref
            .read(navigationSessionProvider.notifier)
            .announceManeuver('Has llegado al destino'),
      );
    }
  }

  void _scheduleReroute() {
    if (_arrived || _simulating || _rerouting) {
      return;
    }
    if (!_hasNetwork()) {
      setState(() {
        _rerouting = false;
        _rerouteError = NavigationUserMessages.rerouteOffline;
      });
      return;
    }
    // No reiniciar si ya hay un intento pendiente.
    if (_rerouteDebounceTimer?.isActive ?? false) {
      return;
    }
    _rerouteDebounceTimer = Timer(NavigationConstants.rerouteDebounce, () {
      unawaited(_rerouteIfNeeded());
    });
  }

  void _scheduleRerouteAfterCooldown() {
    if (_simulating || !_offRoute || !_hasNetwork()) {
      return;
    }
    final last = _lastRerouteAt;
    final wait = last == null
        ? NavigationConstants.rerouteDebounce
        : NavigationConstants.rerouteCooldown - DateTime.now().difference(last);
    _rerouteDebounceTimer?.cancel();
    _rerouteDebounceTimer = Timer(
      wait.isNegative ? NavigationConstants.rerouteDebounce : wait,
      () => unawaited(_rerouteIfNeeded()),
    );
  }

  bool get _canRerouteNow {
    final last = _lastRerouteAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >=
        NavigationConstants.rerouteCooldown;
  }

  bool _hasNetwork() =>
      ref.read(mapNetworkAvailableProvider).asData?.value ?? true;

  Future<void> _rerouteIfNeeded({
    bool force = false,
    bool announce = true,
  }) async {
    if (!mounted || _simulating || _rerouting) {
      return;
    }
    if (!_offRoute && !force) {
      return;
    }
    if (!_hasNetwork()) {
      setState(() {
        _rerouting = false;
        _rerouteError = NavigationUserMessages.rerouteOffline;
      });
      return;
    }
    if (!force && !_canRerouteNow) {
      _scheduleRerouteAfterCooldown();
      return;
    }

    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      setState(() {
        _rerouteError = 'Sin GPS para recalcular.';
      });
      return;
    }

    setState(() {
      _rerouting = true;
      _rerouteError = null;
    });
    _lastRerouteAt = DateTime.now();

    final session = ref.read(navigationSessionProvider.notifier);
    if (announce) {
      unawaited(session.announceManeuver('Recalculando ruta'));
    }

    try {
      final from = GeoPoint(lat: own.lat, lng: own.lng);
      late final NavigationRoute newRoute;
      if (_chasingCabecera) {
        final cabecera = _resolveLiveCabecera();
        if (cabecera == null) {
          if (mounted) {
            setState(() => _rerouting = false);
          }
          return;
        }
        newRoute = await session.planCatchUpRoute(
          from: from,
          to: cabecera.point,
          destinationLabel: cabecera.name,
        );
        _lastChaseTarget = cabecera.point;
      } else {
        newRoute = await session.recalculateRoute(
          currentRoute: _route,
          from: from,
        );
      }
      if (!mounted) {
        return;
      }
      _applyActiveRoute(
        newRoute,
        from: from,
        speedMps: own.speedMps,
      );
    } on NavigationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rerouting = false;
        _rerouteError = navigationUserMessage(error);
      });
      _scheduleRerouteAfterCooldown();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rerouting = false;
        _rerouteError = navigationUserMessage(error);
      });
      _scheduleRerouteAfterCooldown();
    }
  }

  void _applyActiveRoute(
    NavigationRoute newRoute, {
    required GeoPoint from,
    required double speedMps,
    bool announceManeuver = true,
  }) {
    final guidance = ref.read(routeGuidanceServiceProvider);
    final startIndex = guidance.resolveUpcomingManeuverIndex(
      position: from,
      route: newRoute,
    );
    final startRemaining = guidance.remainingMetersToUpcoming(
      position: from,
      route: newRoute,
      upcomingIndex: startIndex,
    );
    final routeRemaining = guidance.remainingRouteMeters(
      position: from,
      route: newRoute,
    );
    final remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: routeRemaining,
      speedMps: speedMps,
      routeDurationSeconds: newRoute.durationSeconds,
      routeDistanceMeters: newRoute.distanceMeters,
    );
    final speedLimit = guidance.resolveSpeedLimitKmh(
      position: from,
      route: newRoute,
    );

    setState(() {
      _route = newRoute;
      _maneuverIndex = startIndex;
      _remainingMeters = startRemaining;
      _routeRemainingMeters = routeRemaining;
      _remainingDuration = remainingDuration;
      _speedLimitKmh = speedLimit;
      _offRoute = false;
      _hasJoinedRoute = true;
      _arrived = false;
      _rerouting = false;
      _rerouteError = null;
      _upcomingAlert = null;
      _upcomingAlertMeters = 0;
      _upcomingFuel = null;
      _upcomingFuelMeters = 0;
      _upcomingToll = null;
      _upcomingTollMeters = 0;
      _announcedAlertIds.clear();
      _announcedManeuverIndices
        ..clear()
        ..addAll(
          newRoute.maneuvers
              .where((m) => m.index < startIndex)
              .map((m) => m.index),
        );
      _arrivalAnnounced = false;
      _cameraFollowUser = true;
    });

    unawaited(_enrichActiveRouteAlerts());

    if (!announceManeuver) {
      return;
    }
    final first = newRoute.maneuvers.elementAtOrNull(startIndex);
    if (first != null) {
      _maybeAnnounceManeuver(
        first,
        remainingMeters: startRemaining,
        force: true,
      );
    }
  }

  ({GeoPoint point, String name})? _resolveLiveCabecera() {
    final groupId = _resolveGroupId();
    if (groupId == null || groupId.isEmpty) {
      return null;
    }
    final members =
        ref.read(groupMembersProvider(groupId)).asData?.value ??
            const <GroupMember>[];
    final locations =
        ref.read(groupLocationsProvider(groupId)).valueOrNull ??
            const <LiveLocation>[];
    final now = DateTime.now();
    for (final member in members) {
      if (member.uid == widget.user.uid) {
        continue;
      }
      if (member.rideRole != RideRole.cabecera) {
        continue;
      }
      LiveLocation? loc;
      for (final item in locations) {
        if (item.uid == member.uid) {
          loc = item;
          break;
        }
      }
      if (loc == null ||
          !loc.hasSignal ||
          isGpsStale(loc.updatedAt, now)) {
        return null;
      }
      return (
        point: GeoPoint(lat: loc.lat, lng: loc.lng),
        name: member.displayName,
      );
    }
    return null;
  }

  bool _shouldJoinSharedGroupRoute(GeoPoint position) {
    final shared = _sharedGroupRoute;
    if (shared == null || shared.polyline.length < 2) {
      return false;
    }
    final cabecera = _resolveLiveCabecera();
    if (cabecera != null) {
      final toCabecera = Geolocator.distanceBetween(
        position.lat,
        position.lng,
        cabecera.point.lat,
        cabecera.point.lng,
      );
      if (toCabecera <= NavigationConstants.deviationThresholdMeters) {
        return true;
      }
    }
    final toPolyline = ref.read(routeDeviationServiceProvider).distanceToPolylineMeters(
          position,
          shared.polyline,
        );
    if (toPolyline > NavigationConstants.deviationThresholdMeters) {
      return false;
    }
    final along = ref.read(routeGuidanceServiceProvider).distanceAlongRouteMeters(
          position,
          shared.polyline,
        );
    // Cerca del origen del pelotón: seguir a la cabecera, no reiniciar la ruta.
    return along >= NavigationConstants.cabeceraChaseJoinMinAlongMeters;
  }

  GeoPoint _guidancePositionHint() {
    final own = ref.read(ownDevicePositionProvider);
    if (own != null) {
      return GeoPoint(lat: own.lat, lng: own.lng);
    }
    return _simulator?.sample().position ?? _route.origin;
  }

  /// La simulación debe seguir el trazado nuevo desde el punto de fusión, no desde el km 0.
  void _retargetSimulatorToRoute(NavigationRoute route, GeoPoint from) {
    if (!_simulating && _simulator == null) {
      return;
    }
    if (route.polyline.length < 2) {
      return;
    }
    _simulator = RouteProgressSimulator(
      polyline: route.polyline,
      speedMps: _simulationSpeedKmh / 3.6,
      initialDistanceAlongMeters: RouteProgressSimulator.distanceAlongNearest(
        from,
        route.polyline,
      ),
    );
  }

  Future<void> _joinSharedGroupRoute() async {
    if (!mounted || !_chasingCabecera || _joiningSharedRoute) {
      return;
    }
    _joiningSharedRoute = true;

    final groupId = _resolveGroupId();
    NavigationRoute? shared;
    if (groupId != null && groupId.isNotEmpty) {
      shared = ref.read(groupSharedRouteProvider(groupId)).asData?.value;
    }
    shared ??= _sharedGroupRoute ?? widget.sharedGroupRoute;
    if (shared == null) {
      _joiningSharedRoute = false;
      return;
    }
    _sharedGroupRoute = shared;

    final from = _guidancePositionHint();
    _applyActiveRoute(
      shared,
      from: from,
      speedMps: _simulating
          ? _simulationSpeedKmh / 3.6
          : (ref.read(ownDevicePositionProvider)?.speedMps ?? 0),
      announceManeuver: false,
    );
    _retargetSimulatorToRoute(shared, from);
    _chasingCabecera = false;
    _cabeceraChaseTimer?.cancel();
    _cabeceraChaseTimer = null;
    _joiningSharedRoute = false;
    unawaited(
      ref
          .read(navigationSessionProvider.notifier)
          .announceManeuver('Ya estás en la ruta del grupo'),
    );
  }

  Future<void> _refreshCabeceraChase() async {
    if (!mounted || !_chasingCabecera || _arrived || _simulating) {
      return;
    }
    final own = ref.read(ownDevicePositionProvider);
    if (own != null) {
      final position = GeoPoint(lat: own.lat, lng: own.lng);
      if (_shouldJoinSharedGroupRoute(position)) {
        await _joinSharedGroupRoute();
        return;
      }
    }
    final cabecera = _resolveLiveCabecera();
    if (cabecera == null) {
      return;
    }
    final last = _lastChaseTarget;
    if (last != null) {
      final moved = Geolocator.distanceBetween(
        last.lat,
        last.lng,
        cabecera.point.lat,
        cabecera.point.lng,
      );
      if (moved < NavigationConstants.arrivalThresholdMeters) {
        return;
      }
    }
    await _rerouteIfNeeded(force: true, announce: false);
  }

  Future<void> _onCabeceraMoved() async {
    if (!_chasingCabecera || _arrived || _simulating || _rerouting) {
      return;
    }
    final cabecera = _resolveLiveCabecera();
    if (cabecera == null) {
      return;
    }
    final last = _lastChaseTarget;
    if (last != null) {
      final moved = Geolocator.distanceBetween(
        last.lat,
        last.lng,
        cabecera.point.lat,
        cabecera.point.lng,
      );
      if (moved < NavigationConstants.cabeceraChaseRetargetMeters) {
        return;
      }
    }
    if (!_canRerouteNow) {
      return;
    }
    await _rerouteIfNeeded(force: true, announce: false);
  }

  void _toggleSimulation() {
    if (_simulating) {
      _pauseSimulation();
    } else if (_simulator != null && !_simulator!.isFinished) {
      _resumeSimulation();
    } else {
      _startSimulation();
    }
  }

  void _pauseSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (!mounted) {
      return;
    }
    // Mantener [routeSimulationActiveProvider] para que el GPS no pise la posición.
    final own = ref.read(ownDevicePositionProvider);
    if (own != null) {
      ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
        lat: own.lat,
        lng: own.lng,
        heading: own.heading,
        speedMps: 0,
        accuracyMeters: own.accuracyMeters,
      );
    }
    setState(() => _simulating = false);
  }

  void _resumeSimulation() {
    if (_simulator == null || _simulator!.isFinished) {
      _startSimulation();
      return;
    }
    ref.read(routeSimulationActiveProvider.notifier).state = true;
    setState(() => _simulating = true);
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(
      NavigationConstants.simulationTickInterval,
      (_) => _onSimulationTick(),
    );
  }

  void _startSimulation() {
    if (_route.polyline.length < 2) {
      return;
    }

    // Parte del punto de la ruta más cercano a tu posición actual
    // (p. ej. Camino de las Torres), no desde el origen de la ruta.
    final own = ref.read(ownDevicePositionProvider);
    final startHint = own == null
        ? _route.origin
        : GeoPoint(lat: own.lat, lng: own.lng);
    final alongMeters = RouteProgressSimulator.distanceAlongNearest(
      startHint,
      _route.polyline,
    );

    _rerouteDebounceTimer?.cancel();
    _simulator = RouteProgressSimulator(
      polyline: _route.polyline,
      speedMps: _simulationSpeedKmh / 3.6,
      initialDistanceAlongMeters: alongMeters,
    );
    ref.read(routeSimulationActiveProvider.notifier).state = true;
    final guidance = ref.read(routeGuidanceServiceProvider);
    final startPosition = _simulator!.sample().position;
    final startIndex = guidance.resolveUpcomingManeuverIndex(
      position: startPosition,
      route: _route,
    );
    final startRemaining = guidance.remainingMetersToUpcoming(
      position: startPosition,
      route: _route,
      upcomingIndex: startIndex,
    );
    final routeRemaining = guidance.remainingRouteMeters(
      position: startPosition,
      route: _route,
    );
    final remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: routeRemaining,
      speedMps: _simulationSpeedKmh / 3.6,
      routeDurationSeconds: _route.durationSeconds,
      routeDistanceMeters: _route.distanceMeters,
    );
    final speedLimit = guidance.resolveSpeedLimitKmh(
      position: startPosition,
      route: _route,
    );
    setState(() {
      _simulating = true;
      _maneuverIndex = startIndex;
      _offRoute = false;
      _hasJoinedRoute = true;
      _rerouting = false;
      _rerouteError = null;
      _remainingMeters = startRemaining;
      _routeRemainingMeters = routeRemaining;
      _remainingDuration = remainingDuration;
      _speedLimitKmh = speedLimit;
      // No re-anunciar maniobras ya dejadas atrás al partir a mitad de ruta.
      _announcedManeuverIndices
        ..clear()
        ..addAll(
          _route.maneuvers
              .where((m) => m.index < startIndex)
              .map((m) => m.index),
        );
    });

    final first = _simulator!.sample();
    _applySimulatedSample(first);

    final upcoming = _route.maneuvers.elementAtOrNull(startIndex);
    if (upcoming != null) {
      _maybeAnnounceManeuver(
        upcoming,
        remainingMeters: startRemaining,
        force: true,
      );
    }

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(
      NavigationConstants.simulationTickInterval,
      (_) => _onSimulationTick(),
    );
  }

  void _onSimulationTick() {
    final simulator = _simulator;
    if (simulator == null || !_simulating) {
      return;
    }
    final sample = simulator.advance(NavigationConstants.simulationTickInterval);
    _applySimulatedSample(sample);
    if (sample.finished) {
      if (_chasingCabecera) {
        unawaited(_joinSharedGroupRoute());
      } else {
        _stopSimulation(keepLastPosition: true);
        _onArrived();
      }
    }
  }

  /// Última publicación de simulación al grupo (evitar saturar RTDB).
  DateTime? _lastSimGroupPublishAt;

  void _applySimulatedSample(RouteSimulationSample sample) {
    ref.read(ownGpsLostProvider.notifier).state = false;
    ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
      lat: sample.position.lat,
      lng: sample.position.lng,
      heading: sample.bearingDegrees,
      speedMps: sample.speedMps,
      accuracyMeters: 5,
    );
    _updateGuidance();
    unawaited(_publishSimulatedLocationToGroup(sample));
  }

  String? _resolveGroupId() {
    if (!widget.enableGroupFeatures) {
      return null;
    }
    final live = ref.read(signedInUserProvider)?.currentGroupId;
    if (live != null && live.isNotEmpty) {
      return live;
    }
    final fromWidget = widget.user.currentGroupId;
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }
    return null;
  }

  /// Envía la posición ficticia al grupo como si fuera GPS real.
  Future<void> _publishSimulatedLocationToGroup(
    RouteSimulationSample sample,
  ) async {
    final groupId = _resolveGroupId();
    if (groupId == null) {
      return;
    }
    final now = DateTime.now();
    final last = _lastSimGroupPublishAt;
    // ~0.7 s: fluido para el mapa del grupo sin saturar Firebase.
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 700)) {
      return;
    }
    _lastSimGroupPublishAt = now;
    try {
      await ref.read(locationRepositoryProvider).publishLocation(
            LiveLocation(
              uid: widget.user.uid,
              groupId: groupId,
              lat: sample.position.lat,
              lng: sample.position.lng,
              heading: sample.bearingDegrees,
              speed: sample.speedMps,
              updatedAt: now,
              displayName: widget.user.displayName,
              hasSignal: true,
            ),
          );
    } catch (error, stack) {
      debugPrint(
        'HUD sim→grupo: no se pudo publicar ($groupId): $error\n$stack',
      );
    }
  }

  void _stopSimulation({bool keepLastPosition = false}) {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulator = null;
    _lastSimGroupPublishAt = null;
    if (mounted) {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
      setState(() => _simulating = false);
      if (!keepLastPosition) {
        unawaited(_restoreRealGpsPosition(updateGuidance: true));
      }
    }
  }

  Future<void> _cleanupLeavingHud() async {
    await _disarmHudDisplay();
    _stopSimulation(keepLastPosition: false);
    _rerouteDebounceTimer?.cancel();
    ref.read(navigationVoiceMutedProvider.notifier).state = false;
    unawaited(ref.read(navigationVoiceServiceProvider).setMuted(false));
    await ref.read(navigationSessionProvider.notifier).stopNavigation();
    await _restoreRealGpsPosition();
  }

  Future<void> _stop() async {
    await _cleanupLeavingHud();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enrichActiveRouteAlerts() async {
    try {
      final enriched =
          await ref.read(routeAlertsServiceProvider).enrich(
                _route,
                preferredFuel: resolveNavigationPreferredFuel(
                  user: widget.user,
                  vehicleId: ref.read(navigationVehicleIdProvider),
                ),
                preferences: ref.read(alertPreferencesProvider),
              );
      if (!mounted || enriched.id != _route.id) {
        return;
      }
      setState(() => _route = enriched);
      _updateGuidance();
    } catch (_) {}
  }

  Future<void> _refreshSpeedLimits() async {
    try {
      final updated = await ref
          .read(navigationRepositoryProvider)
          .refreshSpeedLimits(_route);
      if (!mounted || updated.id != _route.id) {
        return;
      }
      if (updated.speedLimitSegments == _route.speedLimitSegments &&
          updated.speedLimitKmh == _route.speedLimitKmh) {
        return;
      }
      setState(() => _route = updated);
      _updateGuidance();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next != null && !_simulating) {
        _updateGuidance();
      }
    });
    ref.listen(mapNetworkAvailableProvider, (previous, next) {
      final online = next.asData?.value ?? true;
      final wasOnline = previous?.asData?.value ?? true;
      if (online && !wasOnline && _offRoute && !_rerouting && !_arrived) {
        _scheduleReroute();
      }
    });

    final groupId = _resolveGroupId();
    ref.listen(groupPackAlertProvider, (previous, next) {
      if (_userToggledGroupVisibility) {
        return;
      }
      if (previous?.showGroupOnNavigation == next.showGroupOnNavigation) {
        return;
      }
      setState(() => _showGroupMates = next.showGroupOnNavigation);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _evaluateHudPackAlerts(groupId);
    });
    final sharedRouteGroupId =
        (groupId != null && groupId.isNotEmpty) ? groupId : '';
    ref.listen(groupSharedRouteProvider(sharedRouteGroupId), (previous, next) {
      if (sharedRouteGroupId.isEmpty) {
        return;
      }
      final shared = next.asData?.value;
      if (shared == null || _arrived) {
        return;
      }
      final fingerprint =
          '${shared.id}|${shared.polyline.length}|${shared.durationSeconds}';
      _sharedGroupRoute = shared;
      if (_lastSharedRouteFingerprint == null) {
        _lastSharedRouteFingerprint = fingerprint;
        return;
      }
      if (_lastSharedRouteFingerprint == fingerprint) {
        return;
      }
      _lastSharedRouteFingerprint = fingerprint;
      if (_chasingCabecera) {
        return;
      }
      setState(() {
        _route = shared;
        _maneuverIndex = 0;
        _offRoute = false;
        _rerouteError = null;
        _hasJoinedRoute = false;
      });
      _updateGuidance();
    });
    ref.listen(groupLocationsProvider(sharedRouteGroupId), (previous, next) {
      if (sharedRouteGroupId.isEmpty || !_chasingCabecera) {
        return;
      }
      unawaited(_onCabeceraMoved());
    });

    final own = ref.watch(ownDevicePositionProvider);
    final mapStyleAsync = ref.watch(hybridMapStylesProvider);
    final hasNetwork =
        ref.watch(mapNetworkAvailableProvider).asData?.value ?? true;
    final bearing = own == null
        ? 0.0
        : _bearingFilter.next(
            resolveNavigationBearing(
              lat: own.lat,
              lng: own.lng,
              headingDegrees: own.heading,
              polyline: _route.polyline,
            ),
            speedMps: own.speedMps,
          );
    final speedKmh = own == null ? 0.0 : own.speedMps * 3.6;
    final gpsLost = !_simulating && ref.watch(ownGpsLostProvider);
    final weakGps = gpsLost ||
        (!_simulating &&
            own?.accuracyMeters != null &&
            own!.accuracyMeters! >= NavigationConstants.weakGpsAccuracyMeters);
    final secondaryAlert = _upcomingAlert != null
        ? _HudSecondarySlot.radar
        : _upcomingToll != null
            ? _HudSecondarySlot.toll
            : _upcomingFuel != null
                ? _HudSecondarySlot.fuel
                : null;
    final maneuver = _currentManeuver;
    final remaining = _remainingDuration;
    final eta = TimeOfDay.fromDateTime(
      DateTime.now().add(remaining),
    );
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenSize = MediaQuery.sizeOf(context);
    final landscape = screenSize.width > screenSize.height;
    final showOffRouteBanner =
        !_arrived && (_offRoute || _rerouting || _rerouteError != null);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          return;
        }
        // Atrás del sistema / AppBar: no dejar coords de simulación.
        unawaited(_cleanupLeavingHud());
      },
      child: OwnPositionWatcher(
        useForegroundService: true,
        child: _wrapGroupPublisher(
          MapNetworkResumeBinder(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: mapStyleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('No se pudo cargar el mapa.'),
            ),
            data: (mapStyles) {
              return _buildHudMapLayer(
                mapStyles: mapStyles,
                hasNetwork: hasNetwork,
                latitude: own?.lat,
                longitude: own?.lng,
                bearing: bearing,
                speedMps: own?.speedMps ?? 0,
                groupId: groupId,
                overlay: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + (landscape ? 40 : 72),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.black.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              if (showOffRouteBanner)
                Positioned(
                  top: topInset + 8,
                  left: 12,
                  right: 12,
                  child: _OffRouteBanner(
                    rerouting: _rerouting,
                    error: _rerouteError,
                    offline: !hasNetwork,
                    onRetry: hasNetwork
                        ? () => unawaited(_rerouteIfNeeded(force: true))
                        : null,
                    onDismiss: () {
                      _rerouteDebounceTimer?.cancel();
                      setState(() {
                        _offRoute = false;
                        _rerouteError = null;
                      });
                    },
                  ),
                ),
              if (_arrived)
                Positioned(
                  top: topInset + 8,
                  left: 12,
                  right: 12,
                  child: _ArrivalCard(
                    destinationLabel: _route.destinationDisplay,
                    onDone: _stop,
                  ),
                )
              else if (maneuver == null && weakGps)
                Positioned(
                  top: topInset + (showOffRouteBanner ? 64 : 8),
                  left: 12,
                  width: landscape ? 220 : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WeakGpsBanner(lost: gpsLost),
                      if (landscape &&
                          (groupId ?? '').isNotEmpty &&
                          !_arrived) ...[
                        const SizedBox(height: 6),
                        _buildLandscapeIncidentRail(groupId!),
                      ],
                    ],
                  ),
                )
              else if (maneuver != null) ...[
                Positioned(
                  top: topInset + (showOffRouteBanner ? 64 : 8),
                  left: 12,
                  width: landscape ? 220 : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NavigationManeuverCard(
                        compact: landscape,
                        maneuver: maneuver,
                        nextManeuver: landscape ? null : _nextManeuver,
                        remainingMeters: _remainingMeters,
                      ),
                      if (landscape &&
                          (groupId ?? '').isNotEmpty &&
                          !_arrived) ...[
                        const SizedBox(height: 6),
                        _buildLandscapeIncidentRail(groupId!),
                      ],
                      if (!landscape &&
                          maneuver.hasLaneGuidance &&
                          _remainingMeters <=
                              NavigationConstants.laneGuidanceShowMeters &&
                          _remainingMeters >=
                              NavigationConstants.laneGuidanceHideMeters) ...[
                        const SizedBox(height: 6),
                        NavigationLaneGuidancePanel(lanes: maneuver.lanes),
                      ],
                      if (weakGps) ...[
                        const SizedBox(height: 6),
                        _WeakGpsBanner(lost: gpsLost),
                      ],
                      if (!landscape &&
                          secondaryAlert == _HudSecondarySlot.radar &&
                          _upcomingAlert != null) ...[
                        const SizedBox(height: 6),
                        _UpcomingRadarBanner(
                          alert: _upcomingAlert!,
                          remainingMeters: _upcomingAlertMeters,
                          imminentMeters: ref
                              .watch(alertPreferencesProvider)
                              .radarImminentMeters,
                        ),
                      ] else if (!landscape &&
                          secondaryAlert == _HudSecondarySlot.toll &&
                          _upcomingToll != null) ...[
                        const SizedBox(height: 6),
                        _UpcomingTollBanner(
                          alert: _upcomingToll!,
                          remainingMeters: _upcomingTollMeters,
                        ),
                      ] else if (!landscape &&
                          secondaryAlert == _HudSecondarySlot.fuel &&
                          _upcomingFuel != null) ...[
                        const SizedBox(height: 6),
                        _UpcomingFuelBanner(
                          alert: _upcomingFuel!,
                          remainingMeters: _upcomingFuelMeters,
                          showPrice: ref
                              .watch(alertPreferencesProvider)
                              .fuelShowPrice,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (!_arrived)
                Positioned(
                  top: topInset + (showOffRouteBanner ? 64 : 8),
                  right: 12,
                  child: _buildHudRoundButtonsColumn(groupId: groupId),
                ),
              if (!hasNetwork && !_arrived)
                Positioned(
                  left: 12,
                  right: landscape ? 220 : 12,
                  bottom: bottomInset +
                      (landscape ? 58 : (groupId != null ? 168 : 92)),
                  child: const OfflineMapBanner(compact: true),
                ),
              if (landscape && !_arrived && (groupId ?? '').isNotEmpty)
                Positioned(
                  left: 10,
                  right: 80,
                  bottom: bottomInset + 72,
                  child: IntercomControlsBar(
                    groupId: groupId!,
                    compact: true,
                    dark: true,
                  ),
                ),
              if (landscape && !_arrived) ...[
                Positioned(
                  left: 10,
                  right: 12,
                  bottom: bottomInset + 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 268,
                        child: Material(
                          elevation: 6,
                          color: (_speedLimitKmh != null &&
                                  _speedLimitKmh! > 0 &&
                                  speedKmh > _speedLimitKmh! + 1)
                              ? const Color(0xFF3B1010).withValues(alpha: 0.96)
                              : NavigationHudTheme.panel.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(14),
                          child: NavigationStatusBar(
                            compact: true,
                            embedded: true,
                            speedKmh: speedKmh,
                            speedLimitKmh: _speedLimitKmh,
                            eta: eta,
                            remaining: remaining,
                            distanceLabel:
                                formatRideDistance(_routeRemainingMeters),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: (groupId ?? '').isNotEmpty
                            ? GroupIncidentSessionPanel(
                                compact: true,
                                embedded: true,
                                drivingMode: true,
                                showBanner: true,
                                showActions: false,
                                groupId: groupId!,
                                user: widget.user,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (_showSimulatorControls) ...[
                        const SizedBox(width: 8),
                        _LandscapeSimBar(
                          simulating: _simulating,
                          hasSimulator: _simulator != null,
                          speedKmh: _simulationSpeedKmh,
                          onBack: _stop,
                          onToggle: _toggleSimulation,
                          onSpeedChanged: (value) {
                            setState(() => _simulationSpeedKmh = value);
                            final simulator = _simulator;
                            if (simulator != null) {
                              simulator.speedMps = value / 3.6;
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (!landscape)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showSimulatorControls)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                          child: Row(
                            children: [
                              _CompactSimChip(
                                icon: Icons.arrow_back_rounded,
                                label: 'Volver',
                                onTap: _stop,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _SimulationSpeedSlider(
                                  speedKmh: _simulationSpeedKmh,
                                  onChanged: (value) {
                                    setState(
                                      () => _simulationSpeedKmh = value,
                                    );
                                    final simulator = _simulator;
                                    if (simulator != null) {
                                      simulator.speedMps = value / 3.6;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CompactSimChip(
                                icon: _simulating
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                label: _simulating
                                    ? 'Pausar'
                                    : (_simulator != null
                                        ? 'Reanudar'
                                        : 'Simular'),
                                emphasized: _simulating,
                                onTap: _toggleSimulation,
                              ),
                            ],
                          ),
                        ),
                      if ((groupId ?? '').isNotEmpty && !_arrived)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: IntercomControlsBar(
                            groupId: groupId!,
                            compact: true,
                            dark: true,
                          ),
                        ),
                      if ((groupId ?? '').isNotEmpty && !_arrived)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: GroupIncidentSessionPanel(
                            compact: false,
                            drivingMode: true,
                            groupId: groupId!,
                            user: widget.user,
                          ),
                        ),
                      if (ref.watch(hudSafetyProvider).helmetMode &&
                          !_arrived)
                        _HelmetModeBar(
                          muted: ref.watch(navigationVoiceMutedProvider),
                          onToggleMute: () {
                            final muted =
                                !ref.read(navigationVoiceMutedProvider);
                            ref
                                .read(navigationVoiceMutedProvider.notifier)
                                .state = muted;
                            unawaited(
                              ref
                                  .read(navigationVoiceServiceProvider)
                                  .setMuted(muted),
                            );
                          },
                          onCancel: _stop,
                        ),
                      NavigationStatusBar(
                        speedKmh: speedKmh,
                        speedLimitKmh: _speedLimitKmh,
                        eta: eta,
                        remaining: remaining,
                        distanceLabel:
                            formatRideDistance(_routeRemainingMeters),
                      ),
                    ],
                  ),
                ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildHudMapLayer({
    required HybridMapStyles mapStyles,
    required bool hasNetwork,
    required double? latitude,
    required double? longitude,
    required double bearing,
    required double speedMps,
    required String? groupId,
    Widget? overlay,
  }) {
    return NavigationMapView(
      key: const ValueKey('navigation-hud-map'),
      route: _route,
      mapStyles: mapStyles,
      hasNetwork: hasNetwork,
      latitude: latitude,
      longitude: longitude,
      bearing: bearing,
      speedMps: speedMps,
      pitch: ref.watch(lowGlMapModeProvider)
          ? 0
          : (ref.watch(hudSafetyProvider).map3dEnabled
              ? NavigationConstants.defaultMapPitch
              : 0),
      show3dBuildings: !ref.watch(lowGlMapModeProvider) &&
          ref.watch(hudSafetyProvider).map3dEnabled,
      lowGlCompat: ref.watch(lowGlMapModeProvider),
      cameraFollowUser: _cameraFollowUser,
      cameraFollowEpoch: _cameraFollowEpoch,
      onCameraFollowChanged: (following) {
        if (_cameraFollowUser == following) {
          return;
        }
        setState(() => _cameraFollowUser = following);
      },
      alertPreferences: ref.watch(alertPreferencesProvider),
      preferDarkMap: ref.watch(effectiveMapDarkProvider),
      puckStyle: resolveNavigationPuckStyle(
        user: widget.user,
        vehicleId: ref.watch(navigationVehicleIdProvider),
      ),
      groupMates: _hudGroupMates(groupId),
      overlay: overlay,
    );
  }

  Widget _buildHudRoundButtonsColumn({String? groupId}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _HudRoundButton(
          tooltip: 'Cerrar navegación',
          icon: Icons.close_rounded,
          onTap: _stop,
        ),
        const SizedBox(height: 4),
        _HudRoundButton(
          tooltip: ref.watch(navigationVoiceMutedProvider)
              ? 'Activar voz'
              : 'Silenciar voz',
          icon: ref.watch(navigationVoiceMutedProvider)
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          onTap: () {
            final muted = !ref.read(navigationVoiceMutedProvider);
            ref.read(navigationVoiceMutedProvider.notifier).state = muted;
            unawaited(
              ref.read(navigationVoiceServiceProvider).setMuted(muted),
            );
          },
        ),
        const SizedBox(height: 4),
        _HudRoundButton(
          tooltip: ref.watch(mapAppearanceProvider).mode.label,
          icon: switch (ref.watch(mapAppearanceProvider).mode) {
            MapAppearanceMode.auto => Icons.brightness_auto_rounded,
            MapAppearanceMode.day => Icons.light_mode_rounded,
            MapAppearanceMode.night => Icons.dark_mode_rounded,
          },
          onTap: () => unawaited(
            ref.read(mapAppearanceProvider.notifier).cycleMode(),
          ),
        ),
        const SizedBox(height: 4),
        _HudRoundButton(
          tooltip: 'Volver a mi posición',
          icon: Icons.my_location_rounded,
          emphasized: !_cameraFollowUser,
          onTap: () {
            setState(() {
              _cameraFollowUser = true;
              _cameraFollowEpoch++;
            });
          },
        ),
        if (groupId != null) ...[
          const SizedBox(height: 4),
          _HudRoundButton(
            tooltip: _showGroupMates
                ? 'Ocultar grupo (mantener: lista)'
                : 'Mostrar grupo (mantener: lista)',
            icon: Icons.groups_rounded,
            emphasized: _showGroupMates,
            onTap: () {
              setState(() {
                _userToggledGroupVisibility = true;
                _showGroupMates = !_showGroupMates;
              });
            },
            onLongPress: () => unawaited(
              showGroupPackListSheet(
                context: context,
                groupId: groupId,
                user: widget.user,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLandscapeIncidentRail(String groupId) {
    return SizedBox(
      width: 48,
      child: Material(
      color: NavigationHudTheme.panel.withValues(alpha: 0.9),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: GroupIncidentSessionPanel(
        compact: true,
        vertical: true,
        embedded: true,
        drivingMode: true,
        showBanner: false,
        groupId: groupId,
        user: widget.user,
      ),
    ),
    );
  }

  /// Si hay grupo, publica GPS/simulación al RTDB desde el HUD y mantiene intercom.
  Widget _wrapGroupPublisher(Widget child) {
    final groupId = _resolveGroupId();
    if (groupId == null) {
      return child;
    }
    return IntercomSessionBinder(
      groupId: groupId,
      child: GroupLiveLocationPublisher(
        user: widget.user,
        child: child,
      ),
    );
  }

  /// Compañeros visibles en el mapa de navegación según ajustes + botón.
  List<HudGroupMate> _hudGroupMates(String? groupId) {
    if (groupId == null || groupId.isEmpty || !_showGroupMates) {
      return const [];
    }
    ref.watch(gpsClockProvider);
    final packPrefs = ref.watch(groupPackAlertProvider);
    final locations =
        ref.watch(groupLocationsProvider(groupId)).valueOrNull ??
            const <LiveLocation>[];
    final members =
        ref.watch(groupMembersProvider(groupId)).asData?.value ??
            const <GroupMember>[];
    final incidents =
        ref.watch(groupIncidentsProvider(groupId)).asData?.value ??
            const <GroupIncident>[];
    final own = ref.watch(ownDevicePositionProvider);
    final names = <String, String>{
      for (final member in members) member.uid: member.displayName,
    };
    final roles = <String, RideRole?>{
      for (final member in members) member.uid: member.rideRole,
    };
    final activeIncidents = <String, GroupIncident>{
      for (final incident in incidents)
        if (incident.active) incident.uid: incident,
    };
    final now = DateTime.now();
    final onlyLeaders =
        packPrefs.mateDisplayMode == GroupMateDisplayMode.cabeceraCola;

    final mates = <HudGroupMate>[];
    for (final location in locations) {
      if (location.uid == widget.user.uid) {
        continue;
      }
      if (members.isNotEmpty &&
          !members.any((member) => member.uid == location.uid)) {
        continue;
      }
      final role = roles[location.uid];
      if (onlyLeaders &&
          role != RideRole.cabecera &&
          role != RideRole.cola) {
        continue;
      }

      final rawName = (names[location.uid] ?? location.displayName).trim();
      final name = rawName.isEmpty ? 'Motero' : rawName;
      final stale =
          !location.hasSignal || isGpsStale(location.updatedAt, now);
      final incident = activeIncidents[location.uid];
      final distanceMeters = own == null
          ? null
          : Geolocator.distanceBetween(
              own.lat,
              own.lng,
              location.lat,
              location.lng,
            );

      final kind = incident != null
          ? HudGroupMateKind.incident
          : role == RideRole.cabecera
              ? HudGroupMateKind.cabecera
              : role == RideRole.cola
                  ? HudGroupMateKind.cola
                  : stale
                      ? HudGroupMateKind.stale
                      : HudGroupMateKind.mate;

      final lines = <String>[name];
      if (role == RideRole.cabecera) {
        lines.add('cabecera');
      } else if (role == RideRole.cola) {
        lines.add('cola');
      }
      if (incident != null) {
        lines.add(incident.type.label);
      }
      if (stale) {
        lines.add('Sin señal');
      } else if (distanceMeters != null) {
        lines.add(formatRideDistance(distanceMeters));
      }

      mates.add(
        HudGroupMate(
          uid: location.uid,
          lat: location.lat,
          lng: location.lng,
          heading: location.heading,
          label: lines.join('\n'),
          isStale: stale,
          kind: kind,
        ),
      );
    }
    return mates;
  }

  void _evaluateHudPackAlerts(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      return;
    }
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    final locations =
        ref.read(groupLocationsProvider(groupId)).valueOrNull ??
            const <LiveLocation>[];
    final members =
        ref.read(groupMembersProvider(groupId)).asData?.value ??
            const <GroupMember>[];
    final names = <String, String>{
      for (final member in members) member.uid: member.displayName,
    };
    final prefs = ref.read(groupPackAlertProvider);
    if (!prefs.enabled || prefs.isPackAlertsMutedAt(DateTime.now())) {
      return;
    }
    final alerts = _packTracker.evaluate(
      ownLat: own.lat,
      ownLng: own.lng,
      others: locations,
      names: names,
      now: DateTime.now(),
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
}

class _SimulationSpeedSlider extends StatelessWidget {
  const _SimulationSpeedSlider({
    required this.speedKmh,
    required this.onChanged,
    this.compact = false,
  });

  final double speedKmh;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = '${speedKmh.round()}';
    return Material(
      color: NavigationHudTheme.panelElevated,
      borderRadius: BorderRadius.circular(compact ? 10 : 20),
      elevation: compact ? 0 : 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 4 : 8, 0, compact ? 4 : 10, 0),
        child: Row(
          children: [
            Icon(
              Icons.speed_rounded,
              size: compact ? 12 : 14,
              color: NavigationHudTheme.textPrimary,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: compact ? 1.5 : 2,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: compact ? 5 : 7,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: compact ? 10 : 12,
                  ),
                  activeTrackColor: NavigationHudTheme.textPrimary,
                  inactiveTrackColor:
                      NavigationHudTheme.textPrimary.withValues(alpha: 0.25),
                  thumbColor: NavigationHudTheme.textPrimary,
                  overlayColor:
                      NavigationHudTheme.textPrimary.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: speedKmh.clamp(20, 140),
                  min: 20,
                  max: 140,
                  divisions: 24,
                  onChanged: onChanged,
                ),
              ),
            ),
            if (!compact)
              Text(
                '$label km/h',
                style: const TextStyle(
                  color: NavigationHudTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(
                  color: NavigationHudTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Controles de simulación compactos (landscape): acoplados abajo a la derecha.
class _LandscapeSimBar extends StatelessWidget {
  const _LandscapeSimBar({
    required this.simulating,
    required this.hasSimulator,
    required this.speedKmh,
    required this.onBack,
    required this.onToggle,
    required this.onSpeedChanged,
  });

  final bool simulating;
  final bool hasSimulator;
  final double speedKmh;
  final VoidCallback onBack;
  final VoidCallback onToggle;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NavigationHudTheme.panel.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LandscapeSimIconButton(
              tooltip: 'Volver',
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            SizedBox(
              width: 112,
              child: _SimulationSpeedSlider(
                speedKmh: speedKmh,
                onChanged: onSpeedChanged,
                compact: true,
              ),
            ),
            _LandscapeSimIconButton(
              tooltip: simulating
                  ? 'Pausar'
                  : (hasSimulator ? 'Reanudar' : 'Simular'),
              icon: simulating
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              emphasized: simulating,
              onTap: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeSimIconButton extends StatelessWidget {
  const _LandscapeSimIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      style: IconButton.styleFrom(
        backgroundColor: emphasized
            ? NavigationHudTheme.warning
            : NavigationHudTheme.panelElevated,
        foregroundColor: NavigationHudTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
    );
  }
}

class _CompactSimChip extends StatelessWidget {
  const _CompactSimChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? NavigationHudTheme.warning
          : NavigationHudTheme.panelElevated,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: NavigationHudTheme.textPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: NavigationHudTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelmetModeBar extends StatelessWidget {
  const _HelmetModeBar({
    required this.muted,
    required this.onToggleMute,
    required this.onCancel,
  });

  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: muted
                      ? NavigationHudTheme.warning
                      : NavigationHudTheme.panelElevated,
                  foregroundColor: NavigationHudTheme.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onToggleMute,
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 28,
                ),
                label: Text(
                  muted ? 'Activar voz' : 'Silenciar',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 28),
                label: const Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _HudSecondarySlot { radar, toll, fuel }

class _WeakGpsBanner extends StatelessWidget {
  const _WeakGpsBanner({this.lost = false});

  final bool lost;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NavigationHudTheme.panel.withValues(alpha: 0.9),
        border: Border.all(
          color: NavigationHudTheme.warning.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lost ? Icons.gps_off_rounded : Icons.gps_not_fixed_rounded,
              size: 18,
              color: NavigationHudTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(
              lost ? 'Sin señal GPS' : 'Señal GPS baja',
              style: const TextStyle(
                color: NavigationHudTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRadarBanner extends StatelessWidget {
  const _UpcomingRadarBanner({
    required this.alert,
    required this.remainingMeters,
    required this.imminentMeters,
  });

  final RouteAlert alert;
  final double remainingMeters;
  final double imminentMeters;

  @override
  Widget build(BuildContext context) {
    final speed = alert.speedLimitKmh;
    final imminent = remainingMeters <= imminentMeters;
    final kind = alert.effectiveRadarKind;
    final title = imminent ? '${kind.shortLabel} · ahora' : kind.shortLabel;
    final kindColor = Color(kind.mapColorArgb);
    final panel = imminent
        ? Color.lerp(const Color(0xFF3A1212), kindColor, 0.35)!
        : Color.lerp(const Color(0xFF252A31), kindColor, 0.22)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: panel.withValues(alpha: 0.94),
        border: Border.all(color: kindColor.withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadarSpeedSign(speedKmh: speed, urgent: imminent, compact: true),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                title,
                style: TextStyle(
                  color: imminent
                      ? const Color(0xFFFFCDD2)
                      : Color.lerp(Colors.white, kindColor, 0.15)!,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRideDistance(remainingMeters),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso compacto de gasolinera: marca + precios apilados + distancia.
class _UpcomingFuelBanner extends StatelessWidget {
  const _UpcomingFuelBanner({
    required this.alert,
    required this.remainingMeters,
    required this.showPrice,
  });

  final RouteAlert alert;
  final double remainingMeters;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final parts = parseFuelAlertParts(alert);
    final brand = FuelBrandStyle.resolve(parts.brand);
    final showFuelPrice = showPrice && parts.hasPrice;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1F24).withValues(alpha: 0.95),
        border: Border.all(
          color: brand.primary.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FuelBrandBadge(style: brand),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        parts.brand,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          height: 1.05,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatRideDistance(remainingMeters),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (showFuelPrice) ...[
                  const SizedBox(height: 4),
                  for (var i = 0; i < parts.prices.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    _FuelPriceRow(line: parts.prices[i]),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FuelPriceRow extends StatelessWidget {
  const _FuelPriceRow({required this.line});

  final FuelPriceLine line;

  @override
  Widget build(BuildContext context) {
    final grade = line.grade;
    final accent = grade.isEmpty
        ? FuelNozzleColors.fallback
        : FuelNozzleColors.accentForGrade(grade);
    final chip = grade.isEmpty
        ? const Color(0xFF546E7A)
        : FuelNozzleColors.chipForGrade(grade);
    final onChip = grade.isEmpty
        ? Colors.white
        : FuelNozzleColors.onChipForGrade(grade);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (grade.isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(minWidth: 40, maxWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: chip,
              borderRadius: BorderRadius.circular(6),
              border: chip == FuelNozzleColors.gasoleoChip
                  ? Border.all(color: Colors.white24)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              grade,
              style: TextStyle(
                color: onChip,
                fontWeight: FontWeight.w800,
                fontSize: grade.length > 3 ? 9 : 10,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          line.priceText,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.1,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _FuelBrandBadge extends StatelessWidget {
  const _FuelBrandBadge({required this.style});

  final FuelBrandStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: style.primary,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: style.primary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.local_gas_station_rounded,
        color: style.onPrimary,
        size: 17,
      ),
    );
  }
}

class _UpcomingTollBanner extends StatelessWidget {
  const _UpcomingTollBanner({
    required this.alert,
    required this.remainingMeters,
  });

  final RouteAlert alert;
  final double remainingMeters;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF2A1F3D).withValues(alpha: 0.94),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF6A1B9A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.toll_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                alert.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatRideDistance(remainingMeters),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Señal circular española (anillo rojo + cifra negra).
class _RadarSpeedSign extends StatelessWidget {
  const _RadarSpeedSign({
    required this.speedKmh,
    required this.urgent,
    this.compact = false,
  });

  final int? speedKmh;
  final bool urgent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasSpeed = speedKmh != null && speedKmh! > 0;
    final size = compact ? 32.0 : 62.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: urgent ? const Color(0xFFFF1744) : const Color(0xFFE53935),
          width: compact ? 3.2 : 5.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        hasSpeed ? '$speedKmh' : '!',
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w900,
          fontSize: hasSpeed
              ? (compact
                  ? (speedKmh! >= 100 ? 11 : 13)
                  : (speedKmh! >= 100 ? 20 : 24))
              : (compact ? 16 : 28),
          height: 1,
        ),
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({
    required this.destinationLabel,
    required this.onDone,
  });

  final String destinationLabel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavigationHudTheme.panel,
        borderRadius: BorderRadius.circular(NavigationHudTheme.panelRadius),
        boxShadow: const [NavigationHudTheme.panelShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Has llegado',
                        style: TextStyle(
                          color: NavigationHudTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fin de la ruta',
                        style: TextStyle(
                          color: NavigationHudTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (destinationLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                destinationLabel,
                style: const TextStyle(
                  color: NavigationHudTheme.textSecondary,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: NavigationHudTheme.accentStrong,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudRoundButton extends StatelessWidget {
  const _HudRoundButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.tooltip,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: emphasized
          ? NavigationHudTheme.accent.withValues(alpha: 0.95)
          : NavigationHudTheme.panel.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            color: emphasized
                ? Colors.white
                : NavigationHudTheme.textPrimary,
            size: 26,
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class _OffRouteBanner extends StatelessWidget {
  const _OffRouteBanner({
    required this.rerouting,
    required this.error,
    required this.offline,
    required this.onRetry,
    required this.onDismiss,
  });

  final bool rerouting;
  final String? error;
  final bool offline;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = rerouting
        ? 'Recalculando ruta…'
        : (error ??
            (offline
                ? NavigationUserMessages.rerouteOffline
                : 'Fuera de ruta · recalculando automáticamente'));

    return Material(
      color: NavigationHudTheme.panelElevated.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (rerouting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NavigationHudTheme.warning,
                ),
              )
            else
              Icon(
                offline ? Icons.wifi_off_rounded : Icons.alt_route_rounded,
                size: 20,
                color: NavigationHudTheme.warning,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: NavigationHudTheme.textPrimary,
                ),
              ),
            ),
            if (onRetry != null && error != null && !rerouting)
              TextButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
