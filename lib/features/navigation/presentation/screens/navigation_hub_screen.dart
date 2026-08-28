import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/core/widgets/app_popup_menu.dart';
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
import 'package:loc_motos/features/navigation/presentation/widgets/navigation_map_my_location_button.dart';
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
  var _mapFollowEpoch = 0;

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
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final place = await showModalBottomSheet<GeocodingPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: !landscape,
      backgroundColor: landscape ? Colors.transparent : null,
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
    // Mantener coordenadas del toque: Photon/Nominatim devuelve el centro del
    // POI/calle, que puede quedar lejos del punto pulsado.
    final resolved = GeocodingPlace(
      displayName: place?.displayName ??
          '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
      location: point,
      shortLabel: place?.shortLabel ?? 'Punto en el mapa',
      secondaryLabel: place?.secondaryLabel,
      category: place?.category,
      osmType: place?.osmType,
      houseNumber: place?.houseNumber,
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

    final straightKm = _estimateItineraryKmStraightLine(
      origin: origin.point,
      destination: destination.point,
      waypoints: waypoints,
    );
    // Línea recta ≈ menor que la ruta real; factor conservador para avisar a tiempo.
    final estimatedRoadKm = straightKm * 1.25;
    final limitKm =
        (NavigationConstants.valhallaMotorcycleMaxDistanceMeters / 1000)
            .round();
    if (estimatedRoadKm >= limitKm) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Itinerario muy largo'),
          content: Text(
            'Este recorrido suma unos ${straightKm.round()} km en línea '
            'recta (~${estimatedRoadKm.round()} km estimados por carretera). '
            'El límite del servidor es ~$limitKm km y puede fallar el cálculo.\n\n'
            'Prueba con menos paradas o un destino más cercano, '
            'o continúa si quieres intentarlo igual.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Calcular igual'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) {
        return;
      }
    }

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

  /// Distancia aproximada del itinerario (suma tramos en línea recta).
  double _estimateItineraryKmStraightLine({
    required GeoPoint origin,
    required GeoPoint destination,
    required List<GeoPoint> waypoints,
  }) {
    final points = <GeoPoint>[origin, ...waypoints, destination];
    var meters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      meters += Geolocator.distanceBetween(
        points[i].lat,
        points[i].lng,
        points[i + 1].lat,
        points[i + 1].lng,
      );
    }
    return meters / 1000;
  }

  Future<void> _resumeOffline() async {
    try {
      await ref.read(navigationSessionProvider.notifier).resumeCachedRoute();
      final route = ref.read(activeNavigationRouteProvider);
      if (route == null || !mounted) {
        return;
      }
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => NavigationHudScreen(route: route, user: widget.user),
        ),
        (route) => route.isFirst,
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

  Future<void> _importGpx() async {
    try {
      final stops = await ref.read(routeGpxServiceProvider).pickAndParse();
      if (stops == null || !mounted) {
        return;
      }
      // Limitar paradas para no saturar Valhalla / la preview.
      const maxStops = 5;
      final trimmed = stops.length <= maxStops
          ? stops
          : [
              stops.first,
              ...stops.sublist(1, stops.length - 1).take(maxStops - 2),
              stops.last,
            ];
      setState(() {
        _originFollowsGps = false;
        _gpsOriginKey = null;
        _itinerary = RouteItinerary(
          stops: [
            for (final stop in trimmed)
              RouteItineraryStop(
                id: _nextStopId(),
                label: stop.label,
                point: stop.point,
              ),
          ],
        );
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPX importado: ${trimmed.length} punto'
            '${trimmed.length == 1 ? '' : 's'}. Pulsa Ver ruta.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo importar el GPX.')),
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
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenSize = MediaQuery.sizeOf(context);

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
                  followEpoch: _mapFollowEpoch,
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
                          offset: AppPopupMenus.offset,
                          elevation: AppPopupMenus.elevation,
                          shadowColor: AppPopupMenus.shadowColor,
                          surfaceTintColor:
                              AppPopupMenus.surfaceTintOf(context),
                          color: AppPopupMenus.colorOf(context),
                          shape: AppPopupMenus.shapeOf(context),
                          onSelected: (value) {
                            if (value == 'resume') {
                              unawaited(_resumeOffline());
                            } else if (value == 'import_gpx') {
                              unawaited(_importGpx());
                            }
                          },
                          itemBuilder: (context) => [
                            appPopupMenuItem(
                              value: 'import_gpx',
                              icon: Icons.upload_file_rounded,
                              label: 'Importar GPX',
                              tint: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                            ),
                            appPopupMenuItem(
                              value: 'resume',
                              icon: Icons.history_rounded,
                              label: 'Continuar ruta guardada',
                              tint: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NavigationMapZoomControls(
                          controller: _mapController!,
                        ),
                        const SizedBox(height: 8),
                        NavigationMapMyLocationButton(
                          enabled: own != null,
                          onPressed: own == null
                              ? null
                              : () {
                                  setState(() => _mapFollowEpoch++);
                                },
                        ),
                      ],
                    ),
                  ),
                if (_itinerary.stops.length >= 2)
                  landscape
                      ? Positioned(
                          left: 8,
                          top: top + 64,
                          bottom: 8,
                          width: (screenSize.width * 0.38).clamp(300.0, 400.0),
                          child: ItinerarySheet(
                            itinerary: _itinerary,
                            busy: busy,
                            onAddStop: () =>
                                _openPlacePicker(title: 'Añadir parada'),
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
                      : Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ItinerarySheet(
                            itinerary: _itinerary,
                            busy: busy,
                            onAddStop: () =>
                                _openPlacePicker(title: 'Añadir parada'),
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
  List<GeocodingPlace> _favorites = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      unawaited(_loadLists());
    });
  }

  Future<void> _loadLists() async {
    final recentRepo = ref.read(recentPlacesRepositoryProvider);
    final favoriteRepo = ref.read(favoritePlacesRepositoryProvider);
    final recents = await recentRepo.list();
    final favorites = await favoriteRepo.list();
    if (!mounted) {
      return;
    }
    setState(() {
      _recents = recents;
      _favorites = favorites;
    });
  }

  bool _isFavorite(GeocodingPlace place) => _favorites.any(
        (item) =>
            item.location.lat == place.location.lat &&
            item.location.lng == place.location.lng,
      );

  Future<void> _toggleFavorite(GeocodingPlace place) async {
    await ref.read(favoritePlacesRepositoryProvider).toggle(place);
    final favorites =
        await ref.read(favoritePlacesRepositoryProvider).list();
    if (!mounted) {
      return;
    }
    setState(() => _favorites = favorites);
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
    final colors = Theme.of(context).colorScheme;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final screenSize = MediaQuery.sizeOf(context);

    if (landscape) {
      final panelWidth = (screenSize.width * 0.4).clamp(300.0, 420.0);
      return Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 0, 8 + bottom),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 12,
            color: colors.surface,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: panelWidth,
              height: screenSize.height - 16 - bottom,
              child: _PlacePickerContent(
                title: widget.title,
                controller: _controller,
                focus: _focus,
                favorites: _favorites,
                recents: _recents,
                isFavorite: _isFavorite,
                onToggleFavorite: (place) => unawaited(_toggleFavorite(place)),
                onSelect: (place) => Navigator.pop(context, place),
                onRemoveRecent: (place) => unawaited(_removeRecent(place)),
                onClearRecents: () => unawaited(_clearRecents()),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _PlacePickerContent(
              title: widget.title,
              controller: _controller,
              focus: _focus,
              favorites: _favorites,
              recents: _recents,
              isFavorite: _isFavorite,
              onToggleFavorite: (place) => unawaited(_toggleFavorite(place)),
              onSelect: (place) => Navigator.pop(context, place),
              onRemoveRecent: (place) => unawaited(_removeRecent(place)),
              onClearRecents: () => unawaited(_clearRecents()),
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeRecent(GeocodingPlace place) async {
    await ref.read(recentPlacesRepositoryProvider).remove(place);
    if (!mounted) {
      return;
    }
    setState(() {
      _recents = _recents
          .where(
            (item) =>
                item.location.lat != place.location.lat ||
                item.location.lng != place.location.lng,
          )
          .toList(growable: false);
    });
  }

  Future<void> _clearRecents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar recientes'),
        content: const Text(
          '¿Quieres eliminar todos los lugares recientes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todos'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(recentPlacesRepositoryProvider).clear();
    if (!mounted) {
      return;
    }
    setState(() => _recents = const []);
  }
}

class _PlacePickerContent extends StatelessWidget {
  const _PlacePickerContent({
    required this.title,
    required this.controller,
    required this.focus,
    required this.favorites,
    required this.recents,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onSelect,
    required this.onRemoveRecent,
    required this.onClearRecents,
    this.scrollController,
  });

  final String title;
  final TextEditingController controller;
  final FocusNode focus;
  final List<GeocodingPlace> favorites;
  final List<GeocodingPlace> recents;
  final bool Function(GeocodingPlace place) isFavorite;
  final ValueChanged<GeocodingPlace> onToggleFavorite;
  final ValueChanged<GeocodingPlace> onSelect;
  final ValueChanged<GeocodingPlace> onRemoveRecent;
  final VoidCallback onClearRecents;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, landscape ? 12 : 12, 16, 24),
      children: [
        if (!landscape)
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        if (!landscape) const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        DestinationSearchField(
          controller: controller,
          focusNode: focus,
          enabled: true,
          labelText: title,
          onSelected: onSelect,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
        ),
        if (favorites.isNotEmpty) ...[
          SizedBox(height: landscape ? 12 : 20),
          Text(
            'Favoritos',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final place in favorites)
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: landscape ? VisualDensity.compact : null,
              leading: Icon(Icons.star_rounded, color: colors.primary),
              title: Text(
                place.primaryLine,
                maxLines: landscape ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: place.contextLine == null
                  ? null
                  : Text(
                      place.contextLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: IconButton(
                tooltip: 'Quitar de favoritos',
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.onSurfaceVariant,
                ),
                onPressed: () => onToggleFavorite(place),
              ),
              onTap: () => onSelect(place),
            ),
        ],
        if (recents.isNotEmpty) ...[
          SizedBox(height: landscape ? 12 : 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recientes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onClearRecents,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.error,
                ),
                child: const Text('Borrar todos'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final place in recents)
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: landscape ? VisualDensity.compact : null,
              leading: const Icon(Icons.history),
              title: Text(
                place.primaryLine,
                maxLines: landscape ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: place.contextLine == null
                  ? null
                  : Text(
                      place.contextLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isFavorite(place)
                        ? 'Quitar de favoritos'
                        : 'Guardar en favoritos',
                    icon: Icon(
                      isFavorite(place)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: isFavorite(place)
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    onPressed: () => onToggleFavorite(place),
                  ),
                  IconButton(
                    tooltip: 'Quitar de recientes',
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => onRemoveRecent(place),
                  ),
                ],
              ),
              onTap: () => onSelect(place),
            ),
        ],
      ],
    );
  }
}
