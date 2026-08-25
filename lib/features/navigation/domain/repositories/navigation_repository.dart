import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_route.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_preferences.dart';

abstract class NavigationRepository {
  /// Calcula ruta online (Valhalla) y la guarda en caché local.
  /// [waypoints] son paradas intermedias (entre origen y destino).
  Future<NavigationRoute> planRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    List<GeoPoint> waypoints = const [],
    RoutePreferences preferences = RoutePreferences.defaults,
    String? originLabel,
    String? destinationLabel,
  });

  /// Recupera la última ruta guardada para usar sin cobertura.
  Future<NavigationRoute?> loadCachedRoute(String routeId);

  /// Última ruta activa del usuario (ruta en mochila).
  Future<NavigationRoute?> loadLastActiveRoute();

  Future<void> saveActiveRoute(NavigationRoute route);

  Future<void> clearActiveRoute();
}
