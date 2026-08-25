import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/data/datasources/hive_route_cache_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_datasource_factory.dart';
import 'package:loc_motos/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/repositories/geocoding_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/repositories/map_region_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/repositories/navigation_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/repositories/recent_places_repository.dart';
import 'package:loc_motos/features/navigation/data/repositories/route_preferences_repository.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_voice_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_deviation_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/hybrid_map_styles.dart';
import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';
import 'package:loc_motos/features/navigation/domain/repositories/geocoding_repository.dart';
import 'package:loc_motos/features/navigation/domain/repositories/map_region_repository.dart';
import 'package:loc_motos/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:loc_motos/features/tracking/presentation/helpers/resolve_own_device_position.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

final navigationRepositoryProvider = Provider<NavigationRepository>((ref) {
  return NavigationRepositoryImpl(
    ValhallaRemoteDataSource(),
    HiveRouteCacheDataSource(),
  );
});

final recentPlacesRepositoryProvider = Provider<RecentPlacesRepository>((ref) {
  return RecentPlacesRepository();
});

final routePreferencesRepositoryProvider =
    Provider<RoutePreferencesRepository>((ref) {
  return RoutePreferencesRepository();
});

final routePreferencesProvider =
    NotifierProvider<RoutePreferencesController, RoutePreferences>(
  RoutePreferencesController.new,
);

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

/// Estilos híbridos: PMTiles local dentro de la CCAA descargada; OpenFreeMap fuera.
final hybridMapStylesProvider = FutureProvider<HybridMapStyles>((ref) async {
  final regions = await ref.watch(availableMapRegionsProvider.future);
  final offline = <OfflineMapStyle>[];
  for (final region in regions) {
    final path = region.localPath;
    if (!region.isDownloaded ||
        path == null ||
        path.startsWith('assets/') ||
        !path.endsWith('.pmtiles')) {
      continue;
    }
    try {
      offline.add(
        OfflineMapStyle(
          regionId: region.id,
          bounds: region.bounds,
          styleString: await NavigationMapStyleService.localPmtilesStyle(path),
        ),
      );
    } catch (_) {
      // Si un pack falla, el resto / online siguen disponibles.
    }
  }
  return HybridMapStyles(
    onlineStyle: await NavigationMapStyleService.onlineStyle(),
    unavailableStyle: NavigationMapStyleService.unavailableStyle(),
    offline: offline,
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

  Future<NavigationRoute> planRoute({
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
      final route = await _repo.planRoute(
        origin: start,
        destination: destination,
        waypoints: waypoints,
        preferences: ref.read(routePreferencesProvider),
        originLabel: originLabel,
        destinationLabel: destinationLabel,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = route;
      state = const AsyncData(null);
      return route;
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
      final route = await _repo.planRoute(
        origin: from,
        destination: currentRoute.destination,
        waypoints: currentRoute.waypoints,
        preferences: ref.read(routePreferencesProvider),
        originLabel: 'Mi ubicación',
        destinationLabel:
            currentRoute.destinationLabel ?? currentRoute.destinationDisplay,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = route;
      return route;
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

  Future<void> announceManeuver(String instruction) {
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
    ref.read(mapDownloadProgressProvider.notifier).state = 0;
    ref.read(mapDownloadBytesProvider.notifier).state =
        (received: 0, total: null);
    ref.read(mapRegionLastActionProvider.notifier).state = null;
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
      state = AsyncError(
        NavigationException(navigationUserMessage(error)),
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
