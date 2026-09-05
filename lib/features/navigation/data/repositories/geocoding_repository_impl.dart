import 'package:moto_amg/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/repositories/geocoding_repository.dart';

class GeocodingRepositoryImpl implements GeocodingRepository {
  GeocodingRepositoryImpl(this._remote);

  final GeocodingRemoteDataSource _remote;

  @override
  Future<List<GeocodingPlace>> searchAddresses(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  }) {
    return _remote.search(query, near: near, thorough: thorough);
  }

  @override
  Future<GeocodingPlace?> reverseGeocode(GeoPoint location) {
    return _remote.reverse(location);
  }
}
