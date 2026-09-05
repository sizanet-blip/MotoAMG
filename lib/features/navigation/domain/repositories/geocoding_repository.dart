import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

abstract interface class GeocodingRepository {
  Future<List<GeocodingPlace>> searchAddresses(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  });

  Future<GeocodingPlace?> reverseGeocode(GeoPoint location);
}
