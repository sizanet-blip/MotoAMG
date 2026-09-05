import 'package:moto_amg/features/navigation/domain/entities/geocoding_place.dart';

/// Ordenación, deduplicación y número aproximado compartidos entre buscadores.
abstract final class GeocodingResultProcessor {
  static List<GeocodingPlace> rankAndDeduplicate(
    List<GeocodingPlace> places, {
    String? requestedHouseNumber,
    int maxResults = 4,
  }) {
    final scored = [...places]
      ..sort((a, b) {
        final scoreDiff = _score(b, requestedHouseNumber)
            .compareTo(_score(a, requestedHouseNumber));
        if (scoreDiff != 0) {
          return scoreDiff;
        }
        return a.displayName.compareTo(b.displayName);
      });

    final seen = <String>{};
    final unique = <GeocodingPlace>[];
    for (final place in scored) {
      final key = _dedupeKey(place);
      if (!seen.add(key)) {
        continue;
      }
      unique.add(place);
      if (unique.length >= maxResults) {
        break;
      }
    }
    return unique;
  }

  static bool hasExactHouseNumber(
    List<GeocodingPlace> places,
    String? requestedHouseNumber,
  ) {
    if (requestedHouseNumber == null) {
      return false;
    }
    return places.any(
      (place) =>
          place.houseNumber?.toLowerCase() ==
          requestedHouseNumber.toLowerCase(),
    );
  }

  static List<GeocodingPlace> applyRequestedHouseNumber(
    List<GeocodingPlace> places,
    String? requestedHouseNumber,
  ) {
    if (requestedHouseNumber == null || places.isEmpty) {
      return places;
    }
    if (hasExactHouseNumber(places, requestedHouseNumber)) {
      return places;
    }

    final bestStreet = places.first;
    final road = bestStreet.shortLabel ?? bestStreet.primaryLine;
    final withNumber = GeocodingPlace(
      displayName: '$road, $requestedHouseNumber, ${bestStreet.displayName}',
      location: bestStreet.location,
      shortLabel: '$road, $requestedHouseNumber',
      secondaryLabel: bestStreet.secondaryLabel,
      category: bestStreet.category,
      osmType: bestStreet.osmType,
      houseNumber: requestedHouseNumber,
      isApproximateHouseNumber: true,
    );

    return [
      withNumber,
      ...places.where((place) => place != bestStreet).take(2),
    ];
  }

  static int _score(GeocodingPlace place, String? requestedHouseNumber) {
    var score = 0;
    final house = place.houseNumber;
    if (requestedHouseNumber != null &&
        house != null &&
        house.toLowerCase() == requestedHouseNumber.toLowerCase()) {
      score += 100;
    } else if (house != null && house.isNotEmpty) {
      score += 40;
    }
    final type = (place.osmType ?? '').toLowerCase();
    final category = (place.category ?? '').toLowerCase();
    if (type == 'house' || type == 'building' || category == 'place') {
      score += 30;
    }
    if (type == 'residential' || type == 'primary' || type == 'secondary') {
      score += 20;
    }
    if (type == 'footway' || type == 'path' || type == 'cycleway') {
      score -= 25;
    }
    return score;
  }

  static String _dedupeKey(GeocodingPlace place) {
    final road = (place.shortLabel ?? place.primaryLine)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final city = (place.secondaryLabel ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final house = (place.houseNumber ?? '').toLowerCase();
    return '$road|$house|$city';
  }
}
