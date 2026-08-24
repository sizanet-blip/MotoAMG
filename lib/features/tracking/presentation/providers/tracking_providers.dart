import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/tracking/data/datasources/location_remote_datasource.dart';
import 'package:loc_motos/features/tracking/data/repositories/location_repository_impl.dart';
import 'package:loc_motos/features/tracking/data/services/device_location_service.dart';
import 'package:loc_motos/features/tracking/domain/entities/live_location.dart';
import 'package:loc_motos/features/tracking/domain/repositories/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(LocationRemoteDataSource());
});

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService();
});

final groupLocationsProvider =
    StreamProvider.family<List<LiveLocation>, String>((ref, groupId) {
      return ref.watch(locationRepositoryProvider).watchGroupLocations(groupId);
    });

/// Última GPS del propio móvil (para centrar el mapa, no Madrid).
final ownDevicePositionProvider = StateProvider<({double lat, double lng})?>(
  (ref) => null,
);

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
