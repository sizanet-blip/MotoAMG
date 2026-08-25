import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_itinerary.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/screens/route_preview_screen.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/destination_search_field.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/itinerary_sheet.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/map_network_resume_binder.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_zoom_controls.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_planner_map.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/offline_map_banner.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/own_position_watcher.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class NavigationHubScreen extends ConsumerStatefulWidget {
  const NavigationHubScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<NavigationHubScreen> createState() =>
      _NavigationHubScreenState();
}

class _NavigationHubScreenState extends ConsumerState<NavigationHubScreen> {
  var _itinerary = const RouteItinerary();
  var _originFollowsGps = true;
  String? _gpsOriginKey;
  MapLibreMapController? _mapController;
  var _stopSeq = 0;

  String _nextStopId() => 'stop_${_stopSeq++}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmupGeocoding());
    });
  }

  Future<void> _warmupGeocoding() async {
    if (NavigationConstants.photonBaseUrl.isEmpty) {
      return;
    }
    try {
      await ref.read(geocodingRepositoryProvider).searchAddresses(
            'Zaragoza',
            near: _biasNear,
          );
    } catch (_) {}
  }

  GeoPoint? get _biasNear {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return null;
    }
    return GeoPoint(lat: own.lat, lng: own.lng);
  }

  void _syncOriginFromGps(double lat, double lng) {
    if (!_originFollowsGps) {
      return;
    }
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_gpsOriginKey == key) {
      return;
    }
    _gpsOriginKey = key;
    unawaited(_loadGpsOrigin(GeoPoint(lat: lat, lng: lng)));
  }

  Future<void> _loadGpsOrigin(GeoPoint point) async {
    GeocodingPlace? place;
    try {
      place = await ref.read(geocodingRepositoryProvider).reverseGeocode(point);
    } catch (_) {
      place = null;
    }
    if (!mounted || !_originFollowsGps) {
      return;
    }
    final label = place?.displayLine ?? 'Mi ubicación';
    final origin = RouteItineraryStop(
      id: _itinerary.origin?.id ?? _nextStopId(),
      label: label,
      point: point,
      followsGps: true,
    );
    setState(() {
      final rest = _itinerary.stops.length <= 1
          ? <RouteItineraryStop>[]
          : _itinerary.stops.sublist(1);
      _itinerary = RouteItinerary(stops: [origin, ...rest]);
    });
  }

  Future<void> _openPlacePicker({
    required String title,
    String? replaceStopId,
  }) async {
    final place = await showModalBottomSheet<GeocodingPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlacePickerSheet(title: title),
    );
    if (place == null || !mounted) {
      return;
    }
    await ref.read(recentPlacesRepositoryProvider).remember(place);
    _applyPlace(place, replaceStopId: replaceStopId);
  }

  void _applyPlace(GeocodingPlace place, {String? replaceStopId}) {
    setState(() {
      final stop = RouteItineraryStop(
        id: replaceStopId ?? _nextStopId(),
        label: place.displayLine,
        point: place.location,
      );
      final stops = [..._itinerary.stops];
      if (replaceStopId != null) {
        final index = stops.indexWhere((item) => item.id == replaceStopId);
        if (index >= 0) {
          if (index == 0) {
            _originFollowsGps = false;
          }
          stops[index] = stop.copyWith(
            followsGps: false,
          );
          _itinerary = RouteItinerary(stops: stops);
          return;
        }
      }
      if (stops.isEmpty) {
        final gps = _biasNear;
        if (gps == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esperando GPS para fijar el origen…'),
            ),
          );
          return;
        }
        stops.add(
          RouteItineraryStop(
            id: _nextStopId(),
            label: 'Mi ubicación',
            point: gps,
            followsGps: true,
          ),
        );
      }
      stops.add(stop);
      _itinerary = RouteItinerary(stops: stops);
    });
  }

  Future<void> _addStopFromMap(LatLng latLng) async {
    final point = GeoPoint(lat: latLng.latitude, lng: latLng.longitude);
    GeocodingPlace? place;
    try {
      place = await ref.read(geocodingRepositoryProvider).reverseGeocode(point);
    } catch (_) {
      place = null;
    }
    if (!mounted) {
      return;
    }
    final resolved = place ??
        GeocodingPlace(
          displayName:
              '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
          location: point,
          shortLabel: 'Punto en el mapa',
        );
    await ref.read(recentPlacesRepositoryProvider).remember(resolved);
    _applyPlace(resolved);
  }

  void _removeStop(String id) {
    setState(() {
      final stops = _itinerary.stops.where((s) => s.id != id).toList();
      if (stops.isEmpty) {
        _originFollowsGps = true;
        _gpsOriginKey = null;
      } else if (stops.first.followsGps) {
        _originFollowsGps = true;
      }
      _itinerary = RouteItinerary(stops: stops);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final stops = [..._itinerary.stops];
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = stops.removeAt(oldIndex);
      stops.insert(newIndex, item);
      // Tras reordenar, solo el índice 0 puede seguir GPS.
      _originFollowsGps = stops.isNotEmpty && stops.first.followsGps;
      _itinerary = RouteItinerary(
        stops: [
          for (var i = 0; i < stops.length; i++)
            stops[i].copyWith(followsGps: i == 0 && stops[i].followsGps),
        ],
      );
    });
  }

  void _closeLoop() {
    final origin = _itinerary.origin;
    if (origin == null) {
      return;
    }
    setState(() {
      _itinerary = RouteItinerary(
        stops: [
          ..._itinerary.stops,
          RouteItineraryStop(
            id: _nextStopId(),
            label: origin.label,
            point: origin.point,
          ),
        ],
      );
    });
  }

  Future<void> _planAndPreview() async {
    final origin = _itinerary.origin;
    final destination = _itinerary.destination;
    if (origin == null || destination == null) {
      return;
    }

    final waypoints = _itinerary.intermediateStops
        .map((stop) => stop.point)
        .toList(growable: false);

    try {
      final plan = await ref.read(navigationSessionProvider.notifier).planRoute(
            origin: origin.point,
            destination: destination.point,
            waypoints: waypoints,
            originLabel: origin.label,
            destinationLabel: destination.label,
          );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutePreviewScreen(plan: plan, user: widget.user),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(navigationUserMessage(error))),
      );
    }
  }

  Future<void> _resumeOffline() async {
    try {
      await ref.read(navigationSessionProvider.notifier).resumeCachedRoute();
      final route = ref.read(activeNavigationRouteProvider);
      if (route == null || !mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NavigationHudScreen(route: route, user: widget.user),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(navigationUserMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = ref.watch(ownDevicePositionProvider);
    final busy = ref.watch(navigationSessionProvider).isLoading;
    final mapStylesAsync = ref.watch(hybridMapStylesProvider);
    final networkAsync = ref.watch(mapNetworkAvailableProvider);
    final hasNetwork = networkAsync.asData?.value ?? true;
    final top = MediaQuery.paddingOf(context).top;

    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next != null) {
        _syncOriginFromGps(next.lat, next.lng);
      }
    });

    if (own != null && _originFollowsGps && _gpsOriginKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _originFollowsGps) {
          _syncOriginFromGps(own.lat, own.lng);
        }
      });
    }

    return OwnPositionWatcher(
      child: MapNetworkResumeBinder(
        child: Scaffold(
          body: mapStylesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('No se pudo cargar el mapa.'),
            ),
            data: (mapStyles) => Stack(
              fit: StackFit.expand,
              children: [
                NavigationPlannerMap(
                  mapStyles: mapStyles,
                  hasNetwork: hasNetwork,
                  stops: _itinerary.stops,
                  latitude: own?.lat,
                  longitude: own?.lng,
                  onMapLongPress: _addStopFromMap,
                  onControllerReady: (controller) {
                    if (_mapController == controller) {
                      return;
                    }
                    setState(() => _mapController = controller);
                  },
                ),
                Positioned(
                  top: top + 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.96),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: BackButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(28),
                          color: Theme.of(context).colorScheme.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: busy
                                ? null
                                : () => _openPlacePicker(
                                      title: _itinerary.canPlan
                                          ? 'Añadir parada'
                                          : '¿A dónde vas?',
                                    ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _itinerary.canPlan
                                          ? 'Añadir parada'
                                          : '¿A dónde vas?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.96),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: PopupMenuButton<String>(
                          tooltip: 'Más opciones',
                          onSelected: (value) {
                            if (value == 'resume') {
                              unawaited(_resumeOffline());
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'resume',
                              child: Text('Continuar ruta guardada'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasNetwork)
                  Positioned(
                    top: top + 64,
                    left: 12,
                    right: 12,
                    child: const OfflineMapBanner(),
                  ),
                if (_mapController != null)
                  Positioned(
                    top: top + 72,
                    right: 12,
                    child: NavigationMapZoomControls(
                      controller: _mapController!,
                    ),
                  ),
                if (_itinerary.stops.length >= 2)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ItinerarySheet(
                      itinerary: _itinerary,
                      busy: busy,
                      onAddStop: () => _openPlacePicker(title: 'Añadir parada'),
                      onRemoveStop: _removeStop,
                      onReorder: _reorder,
                      onCloseLoop: _closeLoop,
                      onPlanRoute: () => unawaited(_planAndPreview()),
                      onEditStop: (id) => _openPlacePicker(
                        title: 'Editar parada',
                        replaceStopId: id,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.94),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Busca un destino o mantén pulsado el mapa para añadir una parada.',
                          textAlign: TextAlign.center,
                        ),
                      ),
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

class _PlacePickerSheet extends ConsumerStatefulWidget {
  const _PlacePickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<_PlacePickerSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<GeocodingPlace> _recents = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      unawaited(_loadRecents());
    });
  }

  Future<void> _loadRecents() async {
    final items = await ref.read(recentPlacesRepositoryProvider).list();
    if (!mounted) {
      return;
    }
    setState(() => _recents = items);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                DestinationSearchField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: true,
                  labelText: widget.title,
                  onSelected: (place) => Navigator.pop(context, place),
                ),
                if (_recents.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Recientes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final place in _recents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(place.primaryLine),
                      subtitle: place.contextLine == null
                          ? null
                          : Text(place.contextLine!),
                      onTap: () => Navigator.pop(context, place),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
