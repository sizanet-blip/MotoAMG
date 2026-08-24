/// Cómo introduce el usuario un punto de ruta (origen o destino).
enum RouteEndpointInputMode {
  address,
  coordinates,
}

extension RouteEndpointInputModeX on RouteEndpointInputMode {
  String get label => switch (this) {
        RouteEndpointInputMode.address => 'Dirección',
        RouteEndpointInputMode.coordinates => 'Coordenadas',
      };
}
