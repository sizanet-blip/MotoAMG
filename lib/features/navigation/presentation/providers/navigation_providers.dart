import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/platform/android_graphics_compat.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';
import 'package:moto_amg/features/auth/domain/entities/user_vehicle.dart';
import 'package:moto_amg/features/auth/domain/entities/vehicle_map_marker.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/navigation/data/datasources/hive_route_cache_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/geocoding_datasource_factory.dart';
import 'package:moto_amg/features/navigation/data/datasources/tomtom_snap_to_roads_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:moto_amg/features/navigation/data/repositories/geocoding_repository_impl.dart';
import 'package:moto_amg/features/navigation/data/repositories/map_region_repository_impl.dart';
import 'package:moto_amg/features/navigation/data/repositories/navigation_repository_impl.dart';
import 'package:moto_amg/features/navigation/data/repositories/alert_preferences_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/hud_safety_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/map_appearance_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/favorite_places_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/recent_places_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/route_preferences_repository.dart';
import 'package:moto_amg/features/navigation/data/repositories/tomtom_preferences_repository.dart';
import 'package:moto_amg/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:moto_amg/features/navigation/data/services/navigation_voice_service.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_fuel_datasource.dart';
import 'package:moto_amg/features/navigation/data/datasources/spain_radar_datasource.dart';
import 'package:moto_amg/features/navigation/data/services/route_alerts_service.dart';
import 'package:moto_amg/features/navigation/data/services/route_deviation_service.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/data/services/route_gpx_service.dart';
import 'package:moto_amg/features/navigation/domain/entities/alert_preferences.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:moto_amg/features/navigation/domain/entities/map_region.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_plan.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_preferences.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:moto_amg/features/navigation/domain/repositories/geocoding_repository.dart';
import 'package:moto_amg/features/navigation/domain/repositories/map_region_repository.dart';
import 'package:moto_amg/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:moto_amg/features/tracking/presentation/helpers/resolve_own_device_position.dart';
import 'package:moto_amg/features/tracking/presentation/providers/tracking_providers.dart';

final navigationRepositoryProvider = Provider<NavigationRepository>((ref) {
  return NavigationRepositoryImpl(
    ValhallaRemoteDataSource(),
    HiveRouteCacheDataSource(),
    tomtom: TomTomSnapToRoadsDataSource(),
  );
});

/// Emulador API ≤30 u OpenGL débil: mapa simplificado para no SIGSEGV.
final androidGraphicsCompatProvider =
    FutureProvider<AndroidGraphicsCompat>((ref) {
  return AndroidGraphicsCompat.detect();
});

final lowGlMapModeProvider = Provider<bool>((ref) {
  return ref.watch(androidGraphicsCompatProvider).asData?.value.useLowGlMapMode ??
      false;
});

final recentPlacesRepositoryProvider = Provider<RecentPlacesRepository>((ref) {
  return RecentPlacesRepository();
});

final favoritePlacesRepositoryProvider =
    Provider<FavoritePlacesRepository>((ref) {
  return FavoritePlacesRepository();
});

final routePreferencesRepositoryProvider =
    Provider<RoutePreferencesRepository>((ref) {
  return RoutePreferencesRepository();
});

final routePreferencesProvider =
    NotifierProvider<RoutePreferencesController, RoutePreferences>(
  RoutePreferencesController.new,
);

final alertPreferencesRepositoryProvider =
    Provider<AlertPreferencesRepository>((ref) {
  return AlertPreferencesRepository();
});

final alertPreferencesProvider =
    NotifierProvider<AlertPreferencesController, AlertPreferences>(
  AlertPreferencesController.new,
);

final mapAppearanceRepositoryProvider = Provider<MapAppearanceRepository>((ref) {
  return MapAppearanceRepository();
});

final mapAppearanceProvider =
    NotifierProvider<MapAppearanceController, MapAppearancePreferences>(
  MapAppearanceController.new,
);

final hudSafetyRepositoryProvider = Provider<HudSafetyRepository>((ref) {
  return HudSafetyRepository();
});

final hudSafetyProvider =
    NotifierProvider<HudSafetyController, HudSafetyPreferences>(
  HudSafetyController.new,
);

final tomtomPreferencesRepositoryProvider =
    Provider<TomTomPreferencesRepository>((ref) {
  return TomTomPreferencesRepository();
});

final tomtomPreferencesProvider =
    NotifierProvider<TomTomPreferencesController, TomTomPreferences>(
  TomTomPreferencesController.new,
);

/// Preferencia de mapa oscuro efectiva (modo + amanecer/atardecer + GPS).
final effectiveMapDarkProvider = Provider<bool>((ref) {
  final mode = ref.watch(mapAppearanceProvider).mode;
  final own = ref.watch(ownDevicePositionProvider);
  return mode.prefersDarkNow(
    latitude: own?.lat,
    longitude: own?.lng,
  );
});

/// Silencio de voz solo durante la sesión de navegación (HUD).
final navigationVoiceMutedProvider = StateProvider<bool>((ref) => false);

/// Id del vehículo elegido para planificar (`null` = sin vehículo / moto por defecto).
final navigationVehicleIdProvider = StateProvider<String?>((ref) => null);

class RoutePreferencesController extends Notifier<RoutePreferences> {
  @override
  RoutePreferences build() {
    Future.microtask(_hydrate);
    return RoutePreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded =
        await ref.read(routePreferencesRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(RoutePreferences next) async {
    state = next;
    await ref.read(routePreferencesRepositoryProvider).save(next);
  }

  Future<void> setCurvature(RouteCurvatureLevel level) {
    return _persist(state.copyWith(curvature: level));
  }

  Future<void> setAvoidHighways(bool value) {
    return _persist(state.copyWith(avoidHighways: value));
  }

  Future<void> setAvoidTolls(bool value) {
    return _persist(state.copyWith(avoidTolls: value));
  }

  Future<void> setAvoidUnpaved(bool value) {
    return _persist(state.copyWith(avoidUnpaved: value));
  }

  Future<void> setAvoidFerries(bool value) {
    return _persist(state.copyWith(avoidFerries: value));
  }
}

class AlertPreferencesController extends Notifier<AlertPreferences> {
  @override
  AlertPreferences build() {
    Future.microtask(_hydrate);
    return AlertPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded =
        await ref.read(alertPreferencesRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(AlertPreferences next) async {
    state = next;
    await ref.read(alertPreferencesRepositoryProvider).save(next);
  }

  Future<void> update(AlertPreferences Function(AlertPreferences) fn) {
    return _persist(fn(state));
  }

  Future<void> reset() => _persist(AlertPreferences.defaults);
}

class MapAppearanceController extends Notifier<MapAppearancePreferences> {
  @override
  MapAppearancePreferences build() {
    Future.microtask(_hydrate);
    return MapAppearancePreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(mapAppearanceRepositoryProvider).load();
    state = loaded;
  }

  Future<void> setMode(MapAppearanceMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(mapAppearanceRepositoryProvider).save(state);
  }

  Future<void> cycleMode() {
    final next = switch (state.mode) {
      MapAppearanceMode.auto => MapAppearanceMode.day,
      MapAppearanceMode.day => MapAppearanceMode.night,
      MapAppearanceMode.night => MapAppearanceMode.auto,
    };
    return setMode(next);
  }
}

class HudSafetyController extends Notifier<HudSafetyPreferences> {
  @override
  HudSafetyPreferences build() {
    Future.microtask(_hydrate);
    return HudSafetyPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(hudSafetyRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(HudSafetyPreferences next) async {
    state = next;
    await ref.read(hudSafetyRepositoryProvider).save(next);
  }

  Future<void> setKeepScreenOn(bool value) {
    return _persist(state.copyWith(keepScreenOn: value));
  }

  Future<void> setHighBrightness(bool value) {
    return _persist(state.copyWith(highBrightness: value));
  }

  Future<void> setHelmetMode(bool value) {
    return _persist(state.copyWith(helmetMode: value));
  }

  Future<void> setMap3dEnabled(bool value) {
    return _persist(state.copyWith(map3dEnabled: value));
  }

  Future<void> setShowRouteSimulator(bool value) {
    return _persist(state.copyWith(showRouteSimulator: value));
  }
}

class TomTomPreferencesController extends Notifier<TomTomPreferences> {
  @override
  TomTomPreferences build() {
    Future.microtask(_hydrate);
    return TomTomPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(tomtomPreferencesRepositoryProvider).load();
    state = loaded;
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await ref.read(tomtomPreferencesRepositoryProvider).save(state);
  }
}

final mapRegionRepositoryProvider = Provider<MapRegionRepository>((ref) {
  return MapRegionRepositoryImpl();
});

final geocodingRepositoryProvider = Provider<GeocodingRepository>((ref) {
  return GeocodingRepositoryImpl(createGeocodingRemoteDataSource());
});

final routeDeviationServiceProvider = Provider<RouteDeviationService>((ref) {
  return RouteDeviationService();
});

final routeGuidanceServiceProvider = Provider<RouteGuidanceService>((ref) {
  return RouteGuidanceService();
});

final spainRadarDatasourceProvider = Provider<SpainRadarDatasource>((ref) {
  return SpainRadarDatasource();
});

final spainFuelDatasourceProvider = Provider<SpainFuelDatasource>((ref) {
  return SpainFuelDatasource();
});

final routeAlertsServiceProvider = Provider<RouteAlertsService>((ref) {
  return RouteAlertsService(
    spainFuel: ref.watch(spainFuelDatasourceProvider),
    spainRadars: ref.watch(spainRadarDatasourceProvider),
  );
});

final routeGpxServiceProvider = Provider<RouteGpxService>((ref) {
  return RouteGpxService();
});

final spainRadarCacheStatusProvider =
    FutureProvider<SpainRadarCacheStatus>((ref) {
  return ref.watch(spainRadarDatasourceProvider).readCacheStatus();
});

final spainFuelCacheStatusProvider =
    FutureProvider<SpainFuelCacheStatus>((ref) {
  return ref.watch(spainFuelDatasourceProvider).readCacheStatus();
});

/// Vehículo elegido al planificar (`null` = sin vehículo / ruta moto por defecto).
UserVehicle? resolveNavigationVehicle({
  required AppUser? user,
  String? vehicleId,
}) {
  if (vehicleId == NavigationConstants.navigationNoVehicleId) {
    return null;
  }
  if (user == null) {
    return null;
  }
  final vehicles = user.resolvedVehicles;
  if (vehicles.isEmpty) {
    return null;
  }
  UserVehicle? selected;
  final id = vehicleId ?? user.activeVehicleId;
  if (id != null && id != NavigationConstants.navigationNoVehicleId) {
    for (final v in vehicles) {
      if (v.id == id) {
        selected = v;
        break;
      }
    }
  }
  if (vehicleId == null) {
    selected ??= user.activeVehicle;
  }
  return selected;
}

/// Combustible del vehículo elegido al planificar (null = mostrar todos).
VehicleFuelType? resolveNavigationPreferredFuel({
  required AppUser? user,
  String? vehicleId,
}) {
  final selected = resolveNavigationVehicle(user: user, vehicleId: vehicleId);
  final fuel = selected?.fuelType;
  if (fuel == null || fuel == VehicleFuelType.unspecified) {
    return null;
  }
  return fuel;
}

/// Estilo del puck GPS (`null` = círculo azul por defecto).
NavigationPuckStyle? resolveNavigationPuckStyle({
  required AppUser? user,
  String? vehicleId,
}) {
  return resolveNavigationVehicle(
    user: user,
    vehicleId: vehicleId,
  )?.navigationPuckStyle;
}

class RadarCacheDownloadState {
  const RadarCacheDownloadState({
    this.downloading = false,
    this.progress,
    this.snackMessage,
  });

  final bool downloading;
  final SpainRadarDownloadProgress? progress;
  final String? snackMessage;

  RadarCacheDownloadState copyWith({
    bool? downloading,
    SpainRadarDownloadProgress? progress,
    String? snackMessage,
    bool clearProgress = false,
    bool clearSnack = false,
  }) {
    return RadarCacheDownloadState(
      downloading: downloading ?? this.downloading,
      progress: clearProgress ? null : (progress ?? this.progress),
      snackMessage: clearSnack ? null : (snackMessage ?? this.snackMessage),
    );
  }
}

class RadarCacheDownloadController extends Notifier<RadarCacheDownloadState> {
  @override
  RadarCacheDownloadState build() => const RadarCacheDownloadState();

  Future<void> download() async {
    if (state.downloading) {
      return;
    }
    state = const RadarCacheDownloadState(downloading: true);
    try {
      final result =
          await ref.read(spainRadarDatasourceProvider).downloadToCache(
        onProgress: (progress) {
          state = state.copyWith(downloading: true, progress: progress);
        },
      );
      ref.invalidate(spainRadarCacheStatusProvider);
      if (result.cancelled) {
        state = const RadarCacheDownloadState(
          snackMessage: 'Descarga cancelada.',
        );
        return;
      }
      if (result.officialCount == 0 && result.osmCount == 0) {
        state = const RadarCacheDownloadState(
          snackMessage:
              'No se pudieron descargar radares. Revisa la conexión.',
        );
        return;
      }
      state = RadarCacheDownloadState(
        snackMessage:
            'Radares listos: ${result.officialCount} oficiales · ${result.osmCount} OSM.',
      );
    } catch (_) {
      state = const RadarCacheDownloadState(
        snackMessage: 'Error al descargar radares.',
      );
    }
  }

  void cancel() {
    ref.read(spainRadarDatasourceProvider).cancelDownload();
  }
}

final radarCacheDownloadProvider =
    NotifierProvider<RadarCacheDownloadController, RadarCacheDownloadState>(
  RadarCacheDownloadController.new,
);

class FuelCacheDownloadState {
  const FuelCacheDownloadState({
    this.downloading = false,
    this.progress,
    this.snackMessage,
  });

  final bool downloading;
  final SpainFuelDownloadProgress? progress;
  final String? snackMessage;

  FuelCacheDownloadState copyWith({
    bool? downloading,
    SpainFuelDownloadProgress? progress,
    String? snackMessage,
    bool clearProgress = false,
    bool clearSnack = false,
  }) {
    return FuelCacheDownloadState(
      downloading: downloading ?? this.downloading,
      progress: clearProgress ? null : (progress ?? this.progress),
      snackMessage: clearSnack ? null : (snackMessage ?? this.snackMessage),
    );
  }
}

class FuelCacheDownloadController extends Notifier<FuelCacheDownloadState> {
  @override
  FuelCacheDownloadState build() => const FuelCacheDownloadState();

  Future<void> download() async {
    if (state.downloading) {
      return;
    }
    state = const FuelCacheDownloadState(downloading: true);
    try {
      final result =
          await ref.read(spainFuelDatasourceProvider).downloadToCache(
        onProgress: (progress) {
          state = state.copyWith(downloading: true, progress: progress);
        },
      );
      ref.invalidate(spainFuelCacheStatusProvider);
      if (result.cancelled) {
        state = const FuelCacheDownloadState(
          snackMessage: 'Descarga cancelada.',
        );
        return;
      }
      if (result.count == 0) {
        state = const FuelCacheDownloadState(
          snackMessage:
              'No se pudieron descargar gasolineras. Revisa la conexión.',
        );
        return;
      }
      state = FuelCacheDownloadState(
        snackMessage: 'Gasolineras listas: ${result.count} estaciones.',
      );
    } catch (_) {
      state = const FuelCacheDownloadState(
        snackMessage: 'Error al descargar gasolineras.',
      );
    }
  }

  void cancel() {
    ref.read(spainFuelDatasourceProvider).cancelDownload();
  }
}

final fuelCacheDownloadProvider =
    NotifierProvider<FuelCacheDownloadController, FuelCacheDownloadState>(
  FuelCacheDownloadController.new,
);

final navigationVoiceServiceProvider = Provider<NavigationVoiceService>((ref) {
  return NavigationVoiceService();
});

final availableMapRegionsProvider = FutureProvider<List<MapRegion>>((ref) {
  return ref.watch(mapRegionRepositoryProvider).listAvailableRegions();
});

bool _hasUsableNetwork(List<ConnectivityResult> results) {
  for (final result in results) {
    if (result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn ||
        result == ConnectivityResult.other) {
      return true;
    }
  }
  return false;
}

/// Conectividad Wi‑Fi / datos (eventos del sistema).
/// Al volver a primer plano se invalida desde el mapa para cubrir el caso del
/// emulador, que a veces no emite el evento al salir del modo avión.
final mapNetworkAvailableProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasUsableNetwork(await connectivity.checkConnectivity());
  await for (final results in connectivity.onConnectivityChanged) {
    yield _hasUsableNetwork(results);
  }
});

/// Estilos híbridos: mismo Protomaps en España (PMTiles local o remoto).
/// Fuera de CCAA con red: OpenFreeMap (fallback).
final hybridMapStylesProvider = FutureProvider<HybridMapStyles>((ref) async {
  final regions = await ref.watch(availableMapRegionsProvider.future);
  final coverage = <OfflineMapStyle>[];
  for (final region in regions) {
    try {
      final path = region.localPath;
      final useLocal = region.isDownloaded &&
          path != null &&
          !path.startsWith('assets/') &&
          path.endsWith('.pmtiles');
      if (useLocal) {
        coverage.add(
          OfflineMapStyle(
            regionId: region.id,
            bounds: region.bounds,
            styleString:
                await NavigationMapStyleService.localPmtilesStyle(path),
            darkStyleString: await NavigationMapStyleService.localPmtilesStyle(
              path,
              dark: true,
            ),
          ),
        );
      } else if (region.downloadUrl.endsWith('.pmtiles')) {
        coverage.add(
          OfflineMapStyle(
            regionId: region.id,
            bounds: region.bounds,
            requiresNetwork: true,
            styleString: await NavigationMapStyleService.remotePmtilesStyle(
              region.downloadUrl,
            ),
            darkStyleString:
                await NavigationMapStyleService.remotePmtilesStyle(
              region.downloadUrl,
              dark: true,
            ),
          ),
        );
      }
    } catch (_) {
      // Si un pack falla, el resto sigue disponible.
    }
  }
  return HybridMapStyles(
    onlineStyle: await NavigationMapStyleService.onlineStyle(),
    onlineStyleDark: await NavigationMapStyleService.onlineStyle(dark: true),
    unavailableStyle: NavigationMapStyleService.unavailableStyle(),
    offline: coverage,
  );
});

/// Compat: estilo inicial según cobertura (sin punto → online o primer offline).
final navigationMapStyleProvider = FutureProvider<String>((ref) async {
  final hybrid = await ref.watch(hybridMapStylesProvider.future);
  final hasNetwork =
      ref.watch(mapNetworkAvailableProvider).asData?.value ?? true;
  if (hybrid.offline.isEmpty) {
    return hasNetwork ? hybrid.onlineStyle : hybrid.unavailableStyle;
  }
  final first = hybrid.offline.first.bounds;
  return hybrid.resolve(
    (first.south + first.north) / 2,
    (first.west + first.east) / 2,
    hasNetwork: hasNetwork,
  );
});

final activeNavigationRouteProvider =
    StateProvider<NavigationRoute?>((ref) => null);

final navigationSessionProvider =
    NotifierProvider<NavigationSessionController, AsyncValue<void>>(
      NavigationSessionController.new,
    );

class NavigationSessionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  NavigationRepository get _repo => ref.read(navigationRepositoryProvider);
  RouteDeviationService get _deviation =>
      ref.read(routeDeviationServiceProvider);
  NavigationVoiceService get _voice => ref.read(navigationVoiceServiceProvider);

  String _resolveCosting() {
    final vehicleId = ref.read(navigationVehicleIdProvider);
    final user = resolveSessionUser(
      ref.read(signedInUserProvider),
      ref.read(authStateProvider).asData?.value,
    );
    final selected = resolveNavigationVehicle(
      user: user,
      vehicleId: vehicleId,
    );
    return selected?.kind.valhallaCosting ??
        NavigationConstants.valhallaCosting;
  }

  Future<RoutePlan> planRoute({
    required GeoPoint destination,
    GeoPoint? origin,
    List<GeoPoint> waypoints = const [],
    String? originLabel,
    String? destinationLabel,
  }) async {
    state = const AsyncLoading();
    try {
      final own = origin == null
          ? await resolveOwnDevicePosition(ref)
          : ref.read(ownDevicePositionProvider);
      final start = origin ??
          (own != null
              ? GeoPoint(lat: own.lat, lng: own.lng)
              : throw const NavigationException(
                  'Activa la ubicación o escribe una dirección.',
                ));
      final costing = _resolveCosting();
      final plan = await _repo.planRoute(
        origin: start,
        destination: destination,
        waypoints: waypoints,
        preferences: ref.read(routePreferencesProvider),
        costing: costing,
        originLabel: originLabel,
        destinationLabel: destinationLabel,
        includeAlternates: true,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = plan.selected;
      state = const AsyncData(null);
      return plan;
    } on NavigationException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      final friendly = NavigationException(navigationUserMessage(error));
      state = AsyncError(friendly, stackTrace);
      throw friendly;
    }
  }

  Future<void> resumeCachedRoute() async {
    state = const AsyncLoading();
    try {
      final route = await _repo.loadLastActiveRoute();
      if (route == null) {
        throw const OfflineRouteUnavailableException();
      }
      ref.read(activeNavigationRouteProvider.notifier).state = route;
      state = const AsyncData(null);
    } on NavigationException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Nueva ruta desde [from] hasta el destino de [currentRoute] (desvío).
  Future<NavigationRoute> recalculateRoute({
    required NavigationRoute currentRoute,
    required GeoPoint from,
  }) async {
    try {
      final plan = await _repo.planRoute(
        origin: from,
        destination: currentRoute.destination,
        waypoints: currentRoute.waypoints,
        preferences: ref.read(routePreferencesProvider),
        costing: _resolveCosting(),
        originLabel: 'Mi ubicación',
        destinationLabel:
            currentRoute.destinationLabel ?? currentRoute.destinationDisplay,
        includeAlternates: false,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = plan.selected;
      return plan.selected;
    } on NavigationException {
      rethrow;
    } catch (error) {
      throw NavigationException(navigationUserMessage(error));
    }
  }

  /// Ruta del rezagado hacia la cabecera (estilo de ruta del usuario).
  Future<NavigationRoute> planCatchUpRoute({
    required GeoPoint from,
    required GeoPoint to,
    required String destinationLabel,
  }) async {
    try {
      final plan = await _repo.planRoute(
        origin: from,
        destination: to,
        waypoints: const [],
        preferences: ref.read(routePreferencesProvider),
        costing: _resolveCosting(),
        originLabel: 'Mi ubicación',
        destinationLabel: destinationLabel,
        includeAlternates: false,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = plan.selected;
      return plan.selected;
    } on NavigationException {
      rethrow;
    } catch (error) {
      throw NavigationException(navigationUserMessage(error));
    }
  }

  Future<void> stopNavigation() async {
    ref.read(activeNavigationRouteProvider.notifier).state = null;
    await _voice.stop();
    state = const AsyncData(null);
  }

  Future<void> announceManeuver(String instruction) async {
    final muted = ref.read(navigationVoiceMutedProvider);
    await _voice.setMuted(muted);
    return _voice.speak(instruction);
  }

  bool checkDeviation(GeoPoint position, NavigationRoute route) {
    return _deviation.isOffRoute(position: position, route: route);
  }
}

final mapRegionActionProvider =
    NotifierProvider<MapRegionActionController, AsyncValue<void>>(
      MapRegionActionController.new,
    );

/// Progreso de descarga 0–1; null si no hay descarga activa.
final mapDownloadProgressProvider = StateProvider<double?>((ref) => null);

/// Bytes recibidos / totales de la descarga activa (para texto MB).
final mapDownloadBytesProvider =
    StateProvider<({int received, int? total})?>((ref) => null);

final mapDownloadingRegionIdProvider = StateProvider<String?>((ref) => null);

/// Última acción completada: `download`, `delete` o null.
final mapRegionLastActionProvider = StateProvider<String?>((ref) => null);

class MapRegionActionController extends Notifier<AsyncValue<void>> {
  var _cancelRequested = false;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> download(String regionId) async {
    _cancelRequested = false;
    state = const AsyncLoading();
    ref.read(mapDownloadingRegionIdProvider.notifier).state = regionId;
    ref.read(mapRegionLastActionProvider.notifier).state = null;

    final regions = ref.read(availableMapRegionsProvider).asData?.value;
    final region = regions?.where((item) => item.id == regionId).firstOrNull;
    final initialBytes = region?.partialBytes ?? 0;
    final totalBytes = region?.sizeBytes;
    ref.read(mapDownloadBytesProvider.notifier).state = (
      received: initialBytes,
      total: totalBytes,
    );
    ref.read(mapDownloadProgressProvider.notifier).state =
        totalBytes != null && totalBytes > 0
            ? (initialBytes / totalBytes).clamp(0.0, 1.0)
            : 0;

    try {
      await ref.read(mapRegionRepositoryProvider).downloadRegion(
        regionId,
        isCancelled: () => _cancelRequested,
        onProgress: (received, total) {
          ref.read(mapDownloadBytesProvider.notifier).state =
              (received: received, total: total);
          if (total == null || total <= 0) {
            return;
          }
          ref.read(mapDownloadProgressProvider.notifier).state =
              (received / total).clamp(0.0, 1.0);
        },
      );
      ref.invalidate(availableMapRegionsProvider);
      ref.invalidate(hybridMapStylesProvider);
      ref.invalidate(navigationMapStyleProvider);
      ref.read(mapRegionLastActionProvider.notifier).state = 'download';
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      ref.invalidate(availableMapRegionsProvider);
      state = AsyncError(
        error is NavigationException
            ? error
            : NavigationException(navigationUserMessage(error)),
        stackTrace,
      );
    } finally {
      ref.read(mapDownloadingRegionIdProvider.notifier).state = null;
      ref.read(mapDownloadProgressProvider.notifier).state = null;
      ref.read(mapDownloadBytesProvider.notifier).state = null;
      _cancelRequested = false;
    }
  }

  void cancelDownload() {
    _cancelRequested = true;
  }

  Future<void> delete(String regionId) async {
    state = const AsyncLoading();
    ref.read(mapRegionLastActionProvider.notifier).state = null;
    try {
      await ref.read(mapRegionRepositoryProvider).deleteRegion(regionId);
      ref.invalidate(availableMapRegionsProvider);
      ref.invalidate(hybridMapStylesProvider);
      ref.invalidate(navigationMapStyleProvider);
      ref.read(mapRegionLastActionProvider.notifier).state = 'delete';
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(
        NavigationException(navigationUserMessage(error)),
        stackTrace,
      );
    }
  }
}
