import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

abstract final class PhotonGeocodingParser {
  static GeocodingPlace? parseFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    final props = feature['properties'] as Map<String, dynamic>?;
    if (coordinates == null || coordinates.length < 2 || props == null) {
      return null;
    }

    final lng = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();
    final countryCode = (props['countrycode'] as String?)?.toUpperCase();
    if (countryCode != null && countryCode != 'ES') {
      return null;
    }

    final street = props['street'] as String?;
    final housenumber = props['housenumber']?.toString();
    final name = props['name'] as String?;
    final city = _pickCity(props);
    final state = props['state'] as String?;

    final shortLabel =
        _primaryLine(street: street, housenumber: housenumber, name: name);
    final secondaryParts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty && state != city) state,
      if (props['country'] case final String country when country.isNotEmpty)
        country,
    ];
    final secondaryLabel =
        secondaryParts.isEmpty ? null : secondaryParts.take(3).join(', ');

    final displayParts = <String>[
      if (shortLabel.isNotEmpty) shortLabel,
      ...secondaryParts,
    ];
    if (displayParts.isEmpty) {
      return null;
    }

    return GeocodingPlace(
      displayName: displayParts.join(', '),
      location: GeoPoint(lat: lat, lng: lng),
      shortLabel: shortLabel,
      secondaryLabel: secondaryLabel,
      category: props['osm_key']?.toString(),
      osmType: props['osm_value']?.toString() ?? props['type']?.toString(),
      houseNumber: housenumber,
    );
  }

  static String _primaryLine({
    required String? street,
    required String? housenumber,
    required String? name,
  }) {
    if (street != null && street.isNotEmpty) {
      return housenumber == null || housenumber.isEmpty
          ? street
          : '$street, $housenumber';
    }
    return name?.trim() ?? '';
  }

  static String? _pickCity(Map<String, dynamic> props) {
    for (final key in ['city', 'town', 'village', 'municipality', 'county']) {
      final value = props[key] as String?;
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
