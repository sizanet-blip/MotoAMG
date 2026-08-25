import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/navigation_bearing.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_progress_simulator.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_maneuver_card.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_status_bar.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/own_position_watcher.dart';

class NavigationHudScreen extends ConsumerStatefulWidget {
  const NavigationHudScreen({
    super.key,
    required this.route,
    required this.user,
  });

  final NavigationRoute route;
  final AppUser user;

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

  /// Ocultar "Simular" al detectar movimiento real (navegación de verdad).
  var _hideSimulatorForRealNav = false;
  var _rerouting = false;
  String? _rerouteError;
  DateTime? _lastRerouteAt;
  var _arrived = false;

  bool get _showSimulatorControls =>
      !_arrived && (_simulating || !_hideSimulatorForRealNav);

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _bootstrapGuidance(_route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final maneuver = _route.maneuvers.elementAtOrNull(_maneuverIndex);
      if (maneuver != null) {
        ref
            .read(navigationSessionProvider.notifier)
            .announceManeuver(maneuver.spokenInstruction);
      }
    });
  }

  void _bootstrapGuidance(NavigationRoute route) {
    final guidance = RouteGuidanceService();
    final maneuvers = route.maneuvers;
    if (maneuvers.length > 1) {
      _maneuverIndex = maneuvers.first.type == ManeuverType.depart ? 1 : 0;
      _remainingMeters = guidance.remainingMetersToUpcoming(
        position: route.origin,
        route: route,
        upcomingIndex: _maneuverIndex,
      );
    } else {
      _maneuverIndex = 0;
      _remainingMeters =
          maneuvers.firstOrNull?.distanceMeters ?? route.distanceMeters;
    }
    _routeRemainingMeters = guidance.remainingRouteMeters(
      position: route.origin,
      route: route,
    );
    _remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: _routeRemainingMeters,
      speedMps: 0,
      routeDurationSeconds: route.durationSeconds,
      routeDistanceMeters: route.distanceMeters,
    );
    _speedLimitKmh = guidance.resolveSpeedLimitKmh(
      position: route.origin,
      route: route,
    );
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _rerouteDebounceTimer?.cancel();
    _rerouteDebounceTimer = null;
    try {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
    } catch (_) {
      // Widget ya desmontado.
    }
    super.dispose();
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
    final session = ref.read(navigationSessionProvider.notifier);
    final guidance = ref.read(routeGuidanceServiceProvider);
    final deviation = ref.read(routeDeviationServiceProvider);

    if (guidance.hasArrived(position: position, route: _route)) {
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
      // Movimiento real: quitar el botón de prueba.
      if (!_hideSimulatorForRealNav &&
          own.speedMps >= NavigationConstants.hideSimulatorSpeedMps) {
        setState(() => _hideSimulatorForRealNav = true);
      }

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

    final maneuverChanged = upcomingIndex != _maneuverIndex;
    final metersChanged = (remaining - _remainingMeters).abs() > 5;
    final routeMetersChanged =
        (routeRemaining - _routeRemainingMeters).abs() > 10;
    final durationChanged =
        (remainingDuration.inSeconds - _remainingDuration.inSeconds).abs() > 5;
    final limitChanged = speedLimit != _speedLimitKmh;

    if (maneuverChanged ||
        metersChanged ||
        routeMetersChanged ||
        durationChanged ||
        limitChanged) {
      setState(() {
        _maneuverIndex = upcomingIndex;
        _remainingMeters = remaining;
        _routeRemainingMeters = routeRemaining;
        _remainingDuration = remainingDuration;
        _speedLimitKmh = speedLimit;
      });
    }
    if (maneuverChanged) {
      final next = _currentManeuver;
      if (next != null) {
        session.announceManeuver(next.spokenInstruction);
      }
    }
  }

  void _onArrived() {
    if (_arrived || !mounted) {
      return;
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
    unawaited(
      ref
          .read(navigationSessionProvider.notifier)
          .announceManeuver('Has llegado al destino'),
    );
  }

  void _scheduleReroute() {
    if (_arrived || _simulating || _rerouting) {
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
    if (_simulating || !_offRoute) {
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

  Future<void> _rerouteIfNeeded({bool force = false}) async {
    if (!mounted || _simulating || _rerouting) {
      return;
    }
    if (!_offRoute && !force) {
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
    unawaited(session.announceManeuver('Recalculando ruta'));

    try {
      final from = GeoPoint(lat: own.lat, lng: own.lng);
      final newRoute = await session.recalculateRoute(
        currentRoute: _route,
        from: from,
      );
      if (!mounted) {
        return;
      }

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
        speedMps: own.speedMps,
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
        _rerouting = false;
        _rerouteError = null;
      });

      final first = newRoute.maneuvers.elementAtOrNull(startIndex);
      if (first != null) {
        unawaited(session.announceManeuver(first.spokenInstruction));
      }
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

  void _toggleSimulation() {
    if (_simulating) {
      _stopSimulation();
    } else {
      _startSimulation();
    }
  }

  void _startSimulation() {
    if (_route.polyline.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta ruta no tiene trazado para simular.')),
      );
      return;
    }

    _rerouteDebounceTimer?.cancel();
    _simulator = RouteProgressSimulator(
      polyline: _route.polyline,
      speedMps: NavigationConstants.simulationSpeedMps,
    );
    ref.read(routeSimulationActiveProvider.notifier).state = true;
    final guidance = ref.read(routeGuidanceServiceProvider);
    final startIndex = guidance.resolveUpcomingManeuverIndex(
      position: _route.origin,
      route: _route,
    );
    final startRemaining = guidance.remainingMetersToUpcoming(
      position: _route.origin,
      route: _route,
      upcomingIndex: startIndex,
    );
    final routeRemaining = guidance.remainingRouteMeters(
      position: _route.origin,
      route: _route,
    );
    final remainingDuration = guidance.estimateRemainingDuration(
      remainingMeters: routeRemaining,
      speedMps: NavigationConstants.simulationSpeedMps,
      routeDurationSeconds: _route.durationSeconds,
      routeDistanceMeters: _route.distanceMeters,
    );
    final speedLimit = guidance.resolveSpeedLimitKmh(
      position: _route.origin,
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
    });

    final first = _simulator!.sample();
    _applySimulatedSample(first);

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
      _stopSimulation(keepLastPosition: true);
      _onArrived();
    }
  }

  void _applySimulatedSample(RouteSimulationSample sample) {
    ref.read(ownDevicePositionProvider.notifier).state = ownDevicePosition(
      lat: sample.position.lat,
      lng: sample.position.lng,
      heading: sample.bearingDegrees,
      speedMps: sample.speedMps,
    );
    _updateGuidance();
  }

  void _stopSimulation({bool keepLastPosition = false}) {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulator = null;
    if (mounted) {
      ref.read(routeSimulationActiveProvider.notifier).state = false;
      setState(() => _simulating = false);
      if (!keepLastPosition) {
        // El GPS real volverá a escribir en cuanto llegue el siguiente fix.
      }
    }
  }

  Future<void> _stop() async {
    _stopSimulation(keepLastPosition: true);
    _rerouteDebounceTimer?.cancel();
    await ref.read(navigationSessionProvider.notifier).stopNavigation();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next != null && !_simulating) {
        _updateGuidance();
      }
    });

    final own = ref.watch(ownDevicePositionProvider);
    final mapStyleAsync = ref.watch(hybridMapStylesProvider);
    final hasNetwork =
        ref.watch(mapNetworkAvailableProvider).asData?.value ?? true;
    final bearing = own == null
        ? 0.0
        : resolveNavigationBearing(
            lat: own.lat,
            lng: own.lng,
            headingDegrees: own.heading,
            polyline: _route.polyline,
          );
    final speedKmh = own == null ? 0.0 : own.speedMps * 3.6;
    final maneuver = _currentManeuver;
    final remaining = _remainingDuration;
    final eta = TimeOfDay.fromDateTime(
      DateTime.now().add(remaining),
    );
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showOffRouteBanner =
        !_arrived && (_offRoute || _rerouting || _rerouteError != null);

    return OwnPositionWatcher(
      child: MapNetworkResumeBinder(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: mapStyleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('No se pudo cargar el mapa.'),
            ),
            data: (mapStyles) => Stack(
            fit: StackFit.expand,
            children: [
              NavigationMapView(
                key: ValueKey(_route.id),
                route: _route,
                mapStyles: mapStyles,
                hasNetwork: hasNetwork,
                latitude: own?.lat,
                longitude: own?.lng,
                bearing: bearing,
                pitch: NavigationConstants.defaultMapPitch,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + 140,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.12),
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
                    onRetry: () => unawaited(_rerouteIfNeeded(force: true)),
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
              else if (maneuver != null)
                Positioned(
                  top: topInset + (showOffRouteBanner ? 64 : 8),
                  left: 12,
                  right: 12,
                  child: NavigationManeuverCard(
                    maneuver: maneuver,
                    nextManeuver: _nextManeuver,
                    remainingMeters: _remainingMeters,
                    onClose: _stop,
                  ),
                ),
              if (_showSimulatorControls) ...[
                Positioned(
                  left: 12,
                  bottom: bottomInset + 118,
                  child: FloatingActionButton.extended(
                    heroTag: 'nav_back',
                    backgroundColor: NavigationHudTheme.panelElevated,
                    foregroundColor: NavigationHudTheme.textPrimary,
                    onPressed: _stop,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: bottomInset + 118,
                  child: FloatingActionButton.extended(
                    heroTag: 'simulate_route',
                    backgroundColor: _simulating
                        ? NavigationHudTheme.warning
                        : NavigationHudTheme.panelElevated,
                    foregroundColor: NavigationHudTheme.textPrimary,
                    onPressed: _toggleSimulation,
                    icon: Icon(_simulating ? Icons.pause : Icons.play_arrow),
                    label: Text(_simulating ? 'Pausar' : 'Simular'),
                  ),
                ),
              ],
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NavigationStatusBar(
                  speedKmh: speedKmh,
                  speedLimitKmh: _speedLimitKmh,
                  eta: eta,
                  remaining: remaining,
                  distanceLabel: formatRideDistance(_routeRemainingMeters),
                ),
              ),
            ],
          ),
        ),
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

class _OffRouteBanner extends StatelessWidget {
  const _OffRouteBanner({
    required this.rerouting,
    required this.error,
    required this.onRetry,
    required this.onDismiss,
  });

  final bool rerouting;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = rerouting
        ? 'Recalculando ruta…'
        : (error ?? 'Te has salido de la ruta. Recalculando…');

    return Material(
      color: NavigationHudTheme.warning.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (rerouting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.warning_amber_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (error != null && !rerouting)
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
