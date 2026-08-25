import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:loc_motos/features/navigation/domain/repositories/geocoding_repository.dart';
import 'package:loc_motos/features/navigation/presentation/models/route_endpoint_input_mode.dart';

GeoPoint? parseCoordinatePair(String latText, String lngText) {
  final lat = double.tryParse(latText.replaceAll(',', '.'));
  final lng = double.tryParse(lngText.replaceAll(',', '.'));
  if (lat == null || lng == null) {
    return null;
  }
  return GeoPoint(lat: lat, lng: lng);
}

/// Resuelve un punto de ruta según el modo activo del campo.
Future<GeoPoint> resolveRoutePoint({
  required GeocodingRepository geocoding,
  required RouteEndpointInputMode mode,
  GeocodingPlace? selectedPlace,
  required String addressQuery,
  required String latText,
  required String lngText,
  GeoPoint? biasNear,
  required String emptyAddressMessage,
  required String emptyCoordinatesMessage,
}) async {
  if (mode == RouteEndpointInputMode.coordinates) {
    final point = parseCoordinatePair(latText, lngText);
    if (point != null) {
      return point;
    }
    throw NavigationException(emptyCoordinatesMessage);
  }

  if (selectedPlace != null) {
    return selectedPlace.location;
  }

  final address = addressQuery.trim();
  if (address.length >= 3) {
    final results = await geocoding.searchAddresses(address, near: biasNear);
    if (results.isEmpty) {
      throw NavigationException(emptyAddressMessage);
    }
    return results.first.location;
  }

  final point = parseCoordinatePair(latText, lngText);
  if (point != null) {
    return point;
  }

  throw NavigationException(emptyAddressMessage);
}

/// Origen: GPS por defecto en modo dirección, o coords si el modo lo indica.
Future<GeoPoint> resolveOriginPoint({
  required GeocodingRepository geocoding,
  required RouteEndpointInputMode mode,
  GeoPoint? gpsPoint,
  GeocodingPlace? selectedPlace,
  required String addressQuery,
  required String latText,
  required String lngText,
  GeoPoint? biasNear,
}) async {
  if (mode == RouteEndpointInputMode.coordinates) {
    final point = parseCoordinatePair(latText, lngText);
    if (point != null) {
      return point;
    }
    throw const NavigationException(
      'Revisa el origen e inténtalo de nuevo.',
    );
  }

  if (selectedPlace != null) {
    return selectedPlace.location;
  }

  final address = addressQuery.trim();
  if (address.length >= 3) {
    final results = await geocoding.searchAddresses(address, near: biasNear);
    if (results.isEmpty) {
      throw const NavigationException(
        'No encontramos el origen. Prueba con más detalle.',
      );
    }
    return results.first.location;
  }

  if (gpsPoint != null) {
    return gpsPoint;
  }

  throw const NavigationException(
    'Activa la ubicación o escribe una dirección.',
  );
}
