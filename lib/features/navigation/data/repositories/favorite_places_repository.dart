import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Sitios favoritos del planificador (persistentes, aparte de recientes).
class FavoritePlacesRepository {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    _box ??= await Hive.openBox<String>(NavigationConstants.favoritePlacesBox);
    return _box!;
  }

  Future<List<GeocodingPlace>> list({
    int limit = NavigationConstants.favoritePlacesMaxEntries,
  }) async {
    final box = await _open();
    final raw = box.get(NavigationConstants.favoritePlacesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .take(limit)
          .map((item) {
            final map = item as Map<String, dynamic>;
            return GeocodingPlace(
              displayName: map['displayName'] as String? ?? '',
              shortLabel: map['shortLabel'] as String?,
              secondaryLabel: map['secondaryLabel'] as String?,
              location: GeoPoint(
                lat: (map['lat'] as num).toDouble(),
                lng: (map['lng'] as num).toDouble(),
              ),
            );
          })
          .where((place) => place.displayName.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isFavorite(GeocodingPlace place) async {
    final current = await list();
    return current.any((item) => _samePlace(item, place));
  }

  Future<void> add(GeocodingPlace place) async {
    final box = await _open();
    final current = await list(limit: 40);
    final next = <GeocodingPlace>[
      place,
      ...current.where((item) => !_samePlace(item, place)),
    ].take(NavigationConstants.favoritePlacesMaxEntries).toList();
    await _persist(box, next);
  }

  Future<void> remove(GeocodingPlace place) async {
    final box = await _open();
    final current = await list(limit: 40);
    final next = current.where((item) => !_samePlace(item, place)).toList();
    await _persist(box, next);
  }

  /// Devuelve `true` si quedó como favorito.
  Future<bool> toggle(GeocodingPlace place) async {
    if (await isFavorite(place)) {
      await remove(place);
      return false;
    }
    await add(place);
    return true;
  }

  Future<void> clear() async {
    final box = await _open();
    await box.delete(NavigationConstants.favoritePlacesKey);
  }

  bool _samePlace(GeocodingPlace a, GeocodingPlace b) =>
      a.location.lat == b.location.lat && a.location.lng == b.location.lng;

  Future<void> _persist(Box<String> box, List<GeocodingPlace> places) async {
    if (places.isEmpty) {
      await box.delete(NavigationConstants.favoritePlacesKey);
      return;
    }
    await box.put(
      NavigationConstants.favoritePlacesKey,
      jsonEncode(
        places
            .map(
              (item) => {
                'displayName': item.displayName,
                'shortLabel': item.shortLabel,
                'secondaryLabel': item.secondaryLabel,
                'lat': item.location.lat,
                'lng': item.location.lng,
              },
            )
            .toList(),
      ),
    );
  }
}
