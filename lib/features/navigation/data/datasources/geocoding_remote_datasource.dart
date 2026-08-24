import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Contrato común para buscadores de direcciones (Nominatim, Photon, etc.).
abstract interface class GeocodingRemoteDataSource {
  Future<List<GeocodingPlace>> search(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  });

  Future<GeocodingPlace?> reverse(GeoPoint location);
}
