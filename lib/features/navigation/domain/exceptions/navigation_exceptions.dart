import 'package:loc_motos/features/navigation/domain/exceptions/navigation_user_message.dart';

class NavigationException implements Exception {
  const NavigationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RouteNotFoundException extends NavigationException {
  const RouteNotFoundException([
    super.message = 'No hay una ruta viable hasta ese destino.',
  ]);
}

class OfflineRouteUnavailableException extends NavigationException {
  const OfflineRouteUnavailableException([
    super.message = 'No hay ninguna ruta guardada para continuar.',
  ]);
}

/// Fallo al descargar un pack de mapa offline.
class MapRegionDownloadException extends NavigationException {
  const MapRegionDownloadException(super.message);
}

/// El usuario canceló la descarga del mapa.
class MapRegionDownloadCancelledException extends NavigationException {
  const MapRegionDownloadCancelledException([
    super.message = NavigationUserMessages.mapDownloadCancelled,
  ]);
}
