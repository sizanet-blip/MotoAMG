class NavigationException implements Exception {
  const NavigationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RouteNotFoundException extends NavigationException {
  const RouteNotFoundException([super.message = 'No se encontró una ruta viable.']);
}

class OfflineRouteUnavailableException extends NavigationException {
  const OfflineRouteUnavailableException([
    super.message = 'No hay ruta guardada para usar sin cobertura.',
  ]);
}
