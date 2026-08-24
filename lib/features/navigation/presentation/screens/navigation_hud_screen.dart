import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/core/utils/navigation_bearing.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_view.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_maneuver_card.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_status_bar.dart';
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
  var _maneuverIndex = 0;
  var _offRoute = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final maneuver = widget.route.maneuvers.elementAtOrNull(_maneuverIndex);
      if (maneuver != null) {
        ref
            .read(navigationSessionProvider.notifier)
            .announceManeuver(maneuver.instruction);
      }
    });
  }

  NavigationManeuver? get _currentManeuver =>
      widget.route.maneuvers.elementAtOrNull(_maneuverIndex);

  NavigationManeuver? get _nextManeuver =>
      widget.route.maneuvers.elementAtOrNull(_maneuverIndex + 1);

  void _updateGuidance() {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    final position = GeoPoint(lat: own.lat, lng: own.lng);
    final session = ref.read(navigationSessionProvider.notifier);
    final offRoute = session.checkDeviation(position, widget.route);
    if (offRoute != _offRoute) {
      setState(() => _offRoute = offRoute);
    }
    final current = _currentManeuver;
    if (current == null) {
      return;
    }
    final deviation = ref.read(routeDeviationServiceProvider);
    final distance = deviation.distanceToPolylineMeters(
      position,
      [current.location],
    );
    if (distance < NavigationConstants.maneuverAdvanceMeters &&
        _maneuverIndex < widget.route.maneuvers.length - 1) {
      setState(() => _maneuverIndex++);
      final next = _currentManeuver;
      if (next != null) {
        session.announceManeuver(next.instruction);
      }
    }
  }

  Future<void> _stop() async {
    await ref.read(navigationSessionProvider.notifier).stopNavigation();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next != null) {
        _updateGuidance();
      }
    });

    final own = ref.watch(ownDevicePositionProvider);
    final mapStyleAsync = ref.watch(navigationMapStyleProvider);
    final bearing = own == null
        ? 0.0
        : resolveNavigationBearing(
            lat: own.lat,
            lng: own.lng,
            headingDegrees: own.heading,
            polyline: widget.route.polyline,
          );
    final speedKmh = own == null ? 0.0 : own.speedMps * 3.6;
    final maneuver = _currentManeuver;
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    final remaining = Duration(
      seconds: (widget.route.durationSeconds - elapsed.inSeconds).clamp(
        0,
        widget.route.durationSeconds,
      ),
    );
    final eta = TimeOfDay.fromDateTime(
      DateTime.now().add(remaining),
    );
    final topInset = MediaQuery.paddingOf(context).top;

    return OwnPositionWatcher(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: mapStyleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('No se pudo cargar el mapa.'),
          ),
          data: (mapStyle) => Stack(
            fit: StackFit.expand,
            children: [
              NavigationMapView(
                route: widget.route,
                styleString: mapStyle,
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
              if (_offRoute)
                Positioned(
                  top: topInset + 8,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: NavigationHudTheme.warning.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Te has salido de la ruta. Vuelve al trazado.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _offRoute = false),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (maneuver != null)
                Positioned(
                  top: topInset + (_offRoute ? 56 : 8),
                  left: 12,
                  right: 12,
                  child: NavigationManeuverCard(
                    maneuver: maneuver,
                    nextManeuver: _nextManeuver,
                    onClose: _stop,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NavigationStatusBar(
                  speedKmh: speedKmh,
                  speedLimitKmh: widget.route.speedLimitKmh,
                  eta: eta,
                  remaining: remaining,
                  distanceLabel: formatRideDistance(
                    maneuver?.distanceMeters ?? widget.route.distanceMeters,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
