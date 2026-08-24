import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/presentation/helpers/resolve_route_point.dart';
import 'package:loc_motos/features/navigation/presentation/models/route_endpoint_input_mode.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:loc_motos/features/navigation/presentation/screens/navigation_hud_screen.dart';
import 'package:loc_motos/features/navigation/presentation/screens/route_preview_screen.dart';
import 'package:loc_motos/features/navigation/presentation/widgets/route_endpoint_field.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:loc_motos/features/tracking/presentation/widgets/own_position_watcher.dart';

class NavigationHubScreen extends ConsumerStatefulWidget {
  const NavigationHubScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<NavigationHubScreen> createState() =>
      _NavigationHubScreenState();
}

class _NavigationHubScreenState extends ConsumerState<NavigationHubScreen> {
  final _originLat = TextEditingController();
  final _originLng = TextEditingController();
  final _originQuery = TextEditingController();
  final _originFocus = FocusNode();
  final _destLat = TextEditingController();
  final _destLng = TextEditingController();
  final _destQuery = TextEditingController();
  final _destFocus = FocusNode();

  GeocodingPlace? _selectedOrigin;
  GeocodingPlace? _selectedDest;
  var _originMode = RouteEndpointInputMode.address;
  var _destMode = RouteEndpointInputMode.address;
  var _originFollowsGps = true;
  String? _gpsOriginKey;

  @override
  void dispose() {
    _originLat.dispose();
    _originLng.dispose();
    _originQuery.dispose();
    _originFocus.dispose();
    _destLat.dispose();
    _destLng.dispose();
    _destQuery.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  GeoPoint? get _biasNear {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return null;
    }
    return GeoPoint(lat: own.lat, lng: own.lng);
  }

  void _syncOriginFromGps(OwnDevicePosition own) {
    if (_originMode != RouteEndpointInputMode.address || !_originFollowsGps) {
      return;
    }
    final point = GeoPoint(lat: own.lat, lng: own.lng);
    final key =
        '${point.lat.toStringAsFixed(4)},${point.lng.toStringAsFixed(4)}';
    if (_gpsOriginKey == key) {
      return;
    }
    _gpsOriginKey = key;
    unawaited(_loadGpsOrigin(point));
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

    final resolved = place ??
        GeocodingPlace(
          displayName: 'Mi ubicación actual',
          location: point,
          shortLabel: 'Mi ubicación actual',
        );

    setState(() {
      _selectedOrigin = resolved;
      _originLat.text = point.lat.toStringAsFixed(6);
      _originLng.text = point.lng.toStringAsFixed(6);
    });
  }

  void _fillGpsCoordinates({
    required TextEditingController lat,
    required TextEditingController lng,
  }) {
    final own = ref.read(ownDevicePositionProvider);
    if (own == null) {
      return;
    }
    lat.text = own.lat.toStringAsFixed(6);
    lng.text = own.lng.toStringAsFixed(6);
  }

  void _useGpsOriginAddress() {
    setState(() {
      _originFollowsGps = true;
      _selectedOrigin = null;
      _originQuery.clear();
      _gpsOriginKey = null;
    });
    final own = ref.read(ownDevicePositionProvider);
    if (own != null) {
      _syncOriginFromGps(own);
    }
  }

  void _useGpsOriginCoordinates() {
    setState(() {
      _originFollowsGps = false;
      _selectedOrigin = null;
      _fillGpsCoordinates(lat: _originLat, lng: _originLng);
    });
  }

  void _useGpsDestCoordinates() {
    setState(() {
      _selectedDest = null;
      _fillGpsCoordinates(lat: _destLat, lng: _destLng);
    });
  }

  void _onOriginEdited() {
    setState(() {
      _originFollowsGps = false;
      _selectedOrigin = null;
    });
  }

  void _applyEndpointMode({
    RouteEndpointInputMode? origin,
    RouteEndpointInputMode? dest,
  }) {
    setState(() {
      if (origin != null) {
        _setOriginMode(origin);
      }
      if (dest != null) {
        _setDestMode(dest);
      }
    });
  }

  void _setOriginMode(RouteEndpointInputMode mode) {
    _originMode = mode;
    if (mode == RouteEndpointInputMode.coordinates) {
      _originFollowsGps = false;
      _prefillCoordsFromSelection(
        lat: _originLat,
        lng: _originLng,
        place: _selectedOrigin,
        fallback: _biasNear,
      );
      return;
    }
    if (_selectedOrigin != null) {
      return;
    }
    if (_originFollowsGps) {
      _gpsOriginKey = null;
      final own = ref.read(ownDevicePositionProvider);
      if (own != null) {
        _syncOriginFromGps(own);
      }
    }
  }

  void _setDestMode(RouteEndpointInputMode mode) {
    _destMode = mode;
    if (mode == RouteEndpointInputMode.coordinates) {
      _prefillCoordsFromSelection(
        lat: _destLat,
        lng: _destLng,
        place: _selectedDest,
      );
    }
  }

  void _prefillCoordsFromSelection({
    required TextEditingController lat,
    required TextEditingController lng,
    GeocodingPlace? place,
    GeoPoint? fallback,
  }) {
    if (lat.text.trim().isNotEmpty && lng.text.trim().isNotEmpty) {
      return;
    }
    final point = place?.location ?? fallback;
    if (point == null) {
      return;
    }
    lat.text = point.lat.toStringAsFixed(6);
    lng.text = point.lng.toStringAsFixed(6);
  }

  Future<void> _planAndPreview() async {
    try {
      final geocoding = ref.read(geocodingRepositoryProvider);
      final origin = await resolveOriginPoint(
        geocoding: geocoding,
        mode: _originMode,
        gpsPoint: _biasNear,
        selectedPlace: _selectedOrigin,
        addressQuery: _originQuery.text,
        latText: _originLat.text,
        lngText: _originLng.text,
        biasNear: _biasNear,
      );
      final destination = await resolveRoutePoint(
        geocoding: geocoding,
        mode: _destMode,
        selectedPlace: _selectedDest,
        addressQuery: _destQuery.text,
        latText: _destLat.text,
        lngText: _destLng.text,
        biasNear: _biasNear,
        emptyAddressMessage:
            'No encontramos esa dirección. Prueba con más detalle o usa coordenadas.',
        emptyCoordinatesMessage:
            'Introduce latitud y longitud válidas para el destino.',
      );
      final route = await ref
          .read(navigationSessionProvider.notifier)
          .planRoute(origin: origin, destination: destination);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutePreviewScreen(route: route, user: widget.user),
        ),
      );
    } on NavigationException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
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
    } on NavigationException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(availableMapRegionsProvider);
    final own = ref.watch(ownDevicePositionProvider);
    final busy = ref.watch(navigationSessionProvider).isLoading ||
        ref.watch(mapRegionActionProvider).isLoading;

    ref.listen(ownDevicePositionProvider, (previous, next) {
      if (next != null) {
        _syncOriginFromGps(next);
      }
    });

    if (own != null &&
        _originMode == RouteEndpointInputMode.address &&
        _originFollowsGps &&
        _gpsOriginKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _originFollowsGps) {
          _syncOriginFromGps(own);
        }
      });
    }

    return OwnPositionWatcher(
      child: Scaffold(
        appBar: AppBar(title: const Text('Navegación')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Navegación híbrida para moto: mapas offline (.pmtiles) + rutas '
              'online (Valhalla) guardadas en el móvil para usar sin cobertura.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Planificar ruta',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        RoutePlanFormatMenu(
                          originMode: _originMode,
                          destMode: _destMode,
                          enabled: !busy,
                          onApply: _applyEndpointMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RouteEndpointField(
                      endpointLabel: 'Origen',
                      mode: _originMode,
                      enabled: !busy,
                      onModeChanged: (mode) =>
                          setState(() => _setOriginMode(mode)),
                      addressController: _originQuery,
                      addressFocus: _originFocus,
                      latController: _originLat,
                      lngController: _originLng,
                      selectedPlace: _selectedOrigin,
                      addressLabelText: 'Origen',
                      addressHintText: own == null
                          ? 'Esperando GPS o escribe una dirección'
                          : 'Mi ubicación o dirección de salida',
                      addressPrefixIcon: Icons.trip_origin,
                      addressExampleHint: own == null
                          ? 'Esperando señal GPS. También puedes buscar una dirección.'
                          : 'Por defecto usamos tu GPS. Escribe para buscar otro origen.',
                      coordinatesLabelText: 'Coordenadas de origen',
                      coordinatesPrefixIcon: Icons.trip_origin,
                      onUseGps: own == null
                          ? null
                          : (_originMode == RouteEndpointInputMode.address
                              ? _useGpsOriginAddress
                              : _useGpsOriginCoordinates),
                      onAddressEdited: _onOriginEdited,
                      onAddressSelected: (place) {
                        setState(() {
                          _originFollowsGps = false;
                          _selectedOrigin = place;
                          _originLat.text =
                              place.location.lat.toStringAsFixed(6);
                          _originLng.text =
                              place.location.lng.toStringAsFixed(6);
                        });
                      },
                      onCoordinatesChanged: () {
                        setState(() {
                          _originFollowsGps = false;
                          _selectedOrigin = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    RouteEndpointField(
                      endpointLabel: 'Destino',
                      mode: _destMode,
                      enabled: !busy,
                      onModeChanged: (mode) =>
                          setState(() => _setDestMode(mode)),
                      addressController: _destQuery,
                      addressFocus: _destFocus,
                      latController: _destLat,
                      lngController: _destLng,
                      selectedPlace: _selectedDest,
                      addressLabelText: '¿A dónde vas?',
                      coordinatesLabelText: 'Coordenadas de destino',
                      coordinatesPrefixIcon: Icons.flag_outlined,
                      onUseGps: own == null || _destMode != RouteEndpointInputMode.coordinates
                          ? null
                          : _useGpsDestCoordinates,
                      onAddressEdited: () =>
                          setState(() => _selectedDest = null),
                      onAddressSelected: (place) {
                        setState(() {
                          _selectedDest = place;
                          _destLat.text =
                              place.location.lat.toStringAsFixed(6);
                          _destLng.text =
                              place.location.lng.toStringAsFixed(6);
                        });
                      },
                      onCoordinatesChanged: () =>
                          setState(() => _selectedDest = null),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : _planAndPreview,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver ruta'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _resumeOffline,
                      icon: const Icon(Icons.offline_bolt),
                      label: const Text('Continuar ruta guardada'),
                    ),
                    if (NavigationConstants.valhallaBaseUrl.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Modo demo: sin servidor Valhalla configurado se usa '
                        'una ruta de ejemplo, pero se guarda igual en caché.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Mapas offline (PMTiles)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            regionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Text('No se pudieron cargar las regiones.'),
              data: (regions) => Column(
                children: [
                  for (final region in regions)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          region.isDownloaded
                              ? Icons.download_done
                              : Icons.map_outlined,
                        ),
                        title: Text(region.name),
                        subtitle: Text(
                          region.isDownloaded
                              ? 'Descargado · MapLibre + .pmtiles'
                              : '${(region.sizeBytes / (1024 * 1024)).round()} MB aprox.',
                        ),
                        trailing: region.isDownloaded
                            ? null
                            : FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => ref
                                          .read(
                                            mapRegionActionProvider.notifier,
                                          )
                                          .download(region.id),
                                child: const Text('Descargar'),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
