import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/features/navigation/data/helpers/photon_geocoding_parser.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

void main() {
  group('PhotonGeocodingParser', () {
    test('parsea feature GeoJSON de Photon', () {
      final place = PhotonGeocodingParser.parseFeature({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-2.5058, 40.9489],
        },
        'properties': {
          'street': 'Paseo de los Olmos',
          'housenumber': '22',
          'city': 'Sigüenza',
          'state': 'Castilla-La Mancha',
          'country': 'España',
          'countrycode': 'ES',
          'osm_key': 'highway',
          'osm_value': 'residential',
        },
      });

      expect(place, isNotNull);
      expect(place!.location, const GeoPoint(lat: 40.9489, lng: -2.5058));
      expect(place.shortLabel, 'Paseo de los Olmos, 22');
      expect(place.houseNumber, '22');
      expect(place.secondaryLabel, contains('Sigüenza'));
    });

    test('descarta resultados fuera de España', () {
      final place = PhotonGeocodingParser.parseFeature({
        'geometry': {'coordinates': [2.3522, 48.8566], 'type': 'Point'},
        'properties': {
          'city': 'Paris',
          'countrycode': 'FR',
          'country': 'France',
        },
      });

      expect(place, isNull);
    });
  });
}
