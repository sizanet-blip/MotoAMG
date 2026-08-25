import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/datasources/fallback_geocoding_datasource.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

void main() {
  group('FallbackGeocodingDataSource', () {
    test('usa el primario cuando responde bien', () async {
      final primary = _FakeGeocoding(
        searchResult: [
          const GeocodingPlace(
            displayName: 'Photon Place',
            location: GeoPoint(lat: 1, lng: 2),
            shortLabel: 'Photon',
          ),
        ],
      );
      final fallback = _FakeGeocoding(
        searchResult: [
          const GeocodingPlace(
            displayName: 'Nominatim Place',
            location: GeoPoint(lat: 3, lng: 4),
            shortLabel: 'Nominatim',
          ),
        ],
      );
      final ds = FallbackGeocodingDataSource(
        primary: primary,
        fallback: fallback,
      );

      final results = await ds.search('calle');
      expect(results.single.shortLabel, 'Photon');
      expect(fallback.searchCalls, 0);
    });

    test('usa el fallback si el primario falla', () async {
      final primary = _FakeGeocoding(
        searchError: const NavigationException('Photon caído'),
      );
      final fallback = _FakeGeocoding(
        searchResult: [
          const GeocodingPlace(
            displayName: 'Nominatim Place',
            location: GeoPoint(lat: 3, lng: 4),
            shortLabel: 'Nominatim',
          ),
        ],
      );
      final ds = FallbackGeocodingDataSource(
        primary: primary,
        fallback: fallback,
      );

      final results = await ds.search('calle');
      expect(results.single.shortLabel, 'Nominatim');
      expect(fallback.searchCalls, 1);
    });
  });
}

class _FakeGeocoding implements GeocodingRemoteDataSource {
  _FakeGeocoding({
    this.searchResult = const [],
    this.searchError,
    this.reverseResult,
  });

  final List<GeocodingPlace> searchResult;
  final Object? searchError;
  final GeocodingPlace? reverseResult;
  var searchCalls = 0;

  @override
  Future<List<GeocodingPlace>> search(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  }) async {
    searchCalls++;
    if (searchError != null) {
      throw searchError!;
    }
    return searchResult;
  }

  @override
  Future<GeocodingPlace?> reverse(GeoPoint location) async => reverseResult;
}
