import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_token_client.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_ws_location_datasource.dart';
import 'package:moto_amg/features/tracking/data/repositories/location_repository_impl.dart';
import 'package:moto_amg/features/tracking/data/services/device_location_service.dart';
import 'package:moto_amg/features/tracking/domain/entities/device_position.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/domain/repositories/location_repository.dart';

/// Una sola instancia WS por app (GPS + avisos + paradas + voz).
final gpsWsLocationDataSourceProvider = Provider<GpsWsLocationDataSource>((ref) {
  return GpsWsLocationDataSource(
    identityLookup: () {
      final local = ref.read(signedInUserProvider);
      final remote = ref.read(authStateProvider).asData?.value;
      final user = local ?? remote;
      if (user == null) return null;
      return (uid: user.uid, displayName: user.displayName);
    },
    tokenClient: GpsTokenClient(
      accessTokenLookup: () => ref.read(motoAmgApiClientProvider).accessToken,
    ),
  );
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(gpsWsLocationDataSourceProvider));
});

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService();
});

final groupLocationsProvider =
    StreamProvider.family<List<LiveLocation>, String>((ref, groupId) {
  return ref.watch(locationRepositoryProvider).watchGroupLocations(groupId);
});

/// Última GPS del propio móvil (posición, rumbo y velocidad).
final ownDevicePositionProvider = StateProvider<OwnDevicePosition?>((ref) => null);

/// True mientras se simula movimiento (el watcher GPS no sobrescribe).
final routeSimulationActiveProvider = StateProvider<bool>((ref) => false);

/// Evita dos suscripciones GPS simultáneas (grupo vs navegación).
enum OwnPositionWatchSource { group, navigation }

final ownPositionWatchSourceProvider =
    StateProvider<OwnPositionWatchSource?>((ref) => null);

/// El GPS de este móvil está apagado o no da señal.
final ownGpsLostProvider = StateProvider<bool>((ref) => false);

/// Reloj para detectar motos que dejaron de actualizar.
final gpsClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 5),
    (_) => DateTime.now(),
  );
});
