import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/data/datasources/hive_route_cache_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_datasource_factory.dart';
import 'package:loc_motos/features/navigation/data/datasources/valhalla_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/repositories/geocoding_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/repositories/map_region_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/repositories/navigation_repository_impl.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_map_style_service.dart';
import 'package:loc_motos/features/navigation/data/services/navigation_voice_service.dart';
import 'package:loc_motos/features/navigation/data/services/route_deviation_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/map_region.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
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

final mapRegionRepositoryProvider = Provider<MapRegionRepository>((ref) {
  return MapRegionRepositoryImpl();
});

final geocodingRepositoryProvider = Provider<GeocodingRepository>((ref) {
  return GeocodingRepositoryImpl(createGeocodingRemoteDataSource());
});

final routeDeviationServiceProvider = Provider<RouteDeviationService>((ref) {
  return RouteDeviationService();
});

final navigationVoiceServiceProvider = Provider<NavigationVoiceService>((ref) {
  return NavigationVoiceService();
});

final availableMapRegionsProvider = FutureProvider<List<MapRegion>>((ref) {
  return ref.watch(mapRegionRepositoryProvider).listAvailableRegions();
});

/// Estilo activo: asset por defecto o JSON inline si hay `.pmtiles` local.
final navigationMapStyleProvider = FutureProvider<String>((ref) async {
  final regions = await ref.watch(availableMapRegionsProvider.future);
  for (final region in regions) {
    final path = region.localPath;
    if (region.isDownloaded &&
        path != null &&
        !path.startsWith('assets/') &&
        path.endsWith('.pmtiles')) {
      return NavigationMapStyleService.localPmtilesStyle(path);
    }
  }
  return NavigationMapStyleService.defaultStyle();
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
                  'No hay posición GPS. Activa la ubicación.',
                ));
      final route = await _repo.planRoute(
        origin: start,
        destination: destination,
      );
      ref.read(activeNavigationRouteProvider.notifier).state = route;
      state = const AsyncData(null);
      return route;
    } on NavigationException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      state = AsyncError(NavigationException(error.toString()), stackTrace);
      rethrow;
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

class MapRegionActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> download(String regionId) async {
    state = const AsyncLoading();
    try {
      await ref.read(mapRegionRepositoryProvider).downloadRegion(regionId);
      ref.invalidate(availableMapRegionsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
