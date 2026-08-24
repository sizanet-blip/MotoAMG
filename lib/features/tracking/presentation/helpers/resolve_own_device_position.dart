import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/tracking/domain/entities/device_position.dart';
import 'package:loc_motos/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:loc_motos/features/tracking/presentation/providers/tracking_providers.dart';

/// Obtiene la posición GPS: caché del provider o lectura directa del GPS.
Future<OwnDevicePosition> resolveOwnDevicePosition(Ref ref) async {
  final cached = ref.read(ownDevicePositionProvider);
  if (cached != null) {
    return cached;
  }

  final gps = ref.read(deviceLocationServiceProvider);
  try {
    await gps.ensurePermission();
    final position = await gps.readPosition();
    if (position == null) {
      throw const NavigationException(
        'No hay posición GPS. Espera unos segundos o sal al exterior.',
      );
    }
    final own = ownDevicePosition(
      lat: position.latitude,
      lng: position.longitude,
      heading: position.heading >= 0 ? position.heading : null,
      speedMps: position.speed >= 0 ? position.speed : 0,
    );
    ref.read(ownDevicePositionProvider.notifier).state = own;
    return own;
  } on LocationException catch (error) {
    throw NavigationException(error.message);
  }
}
