import 'package:moto_amg/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

/// Intenta el buscador principal; si falla (caída, timeout, 5xx), usa el de respaldo.
class FallbackGeocodingDataSource implements GeocodingRemoteDataSource {
  FallbackGeocodingDataSource({
    required GeocodingRemoteDataSource primary,
    required GeocodingRemoteDataSource fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final GeocodingRemoteDataSource _primary;
  final GeocodingRemoteDataSource _fallback;

  @override
  Future<List<GeocodingPlace>> search(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  }) async {
    try {
      return await _primary.search(
        query,
        near: near,
        thorough: thorough,
      );
    } catch (_) {
      return _fallback.search(
        query,
        near: near,
        thorough: thorough,
      );
    }
  }

  @override
  Future<GeocodingPlace?> reverse(GeoPoint location) async {
    try {
      final place = await _primary.reverse(location);
      if (place != null) {
        return place;
      }
    } catch (_) {
      // Continúa con el fallback.
    }
    return _fallback.reverse(location);
  }
}
