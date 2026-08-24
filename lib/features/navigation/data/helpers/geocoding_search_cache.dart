import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Caché en memoria de búsquedas recientes por backend.
final class GeocodingSearchCache {
  GeocodingSearchCache(this._prefix);

  final String _prefix;
  final _entries = <String, List<GeocodingPlace>>{};

  String key(String query, GeoPoint? near, bool thorough) {
    final bias = near == null
        ? ''
        : '${near.lat.toStringAsFixed(3)}|${near.lng.toStringAsFixed(3)}';
    return '$_prefix|${thorough ? 't' : 'q'}|$query|$bias';
  }

  List<GeocodingPlace>? read(String key) => _entries[key];

  List<GeocodingPlace> write(String key, List<GeocodingPlace> results) {
    if (_entries.length >= NavigationConstants.geocodingCacheMaxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = results;
    return results;
  }
}
