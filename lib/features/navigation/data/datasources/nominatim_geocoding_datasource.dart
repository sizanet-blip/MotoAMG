import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_query_normalizer.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_result_processor.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_search_cache.dart';
import 'package:loc_motos/features/navigation/data/helpers/nominatim_rate_limiter.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

class NominatimGeocodingDataSource implements GeocodingRemoteDataSource {
  NominatimGeocodingDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final _rateLimiter = NominatimRateLimiter.instance;
  final _cache = GeocodingSearchCache('nominatim');

  @override
  Future<List<GeocodingPlace>> search(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return const [];
    }

    final cacheKey = _cache.key(trimmed, near, thorough);
    final cached = _cache.read(cacheKey);
    if (cached != null) {
      return cached;
    }

    final requestedNumber =
        GeocodingQueryNormalizer.extractHouseNumber(trimmed);
    final variants = _variantsForSearch(trimmed, thorough: thorough);

    List<GeocodingPlace> best = const [];
    for (final variant in variants) {
      final results = await _fetchVariant(variant, near: near);
      if (results.isEmpty) {
        continue;
      }
      final ranked = GeocodingResultProcessor.rankAndDeduplicate(
        results,
        requestedHouseNumber: requestedNumber,
      );
      if (GeocodingResultProcessor.hasExactHouseNumber(
        ranked,
        requestedNumber,
      )) {
        return _cache.write(cacheKey, ranked);
      }
      if (best.isEmpty) {
        best = ranked;
      }
      if (!thorough && best.isNotEmpty) {
        break;
      }
    }

    if (best.isEmpty) {
      return const [];
    }
    return _cache.write(
      cacheKey,
      GeocodingResultProcessor.applyRequestedHouseNumber(
        best,
        requestedNumber,
      ),
    );
  }

  List<GeocodingSearchVariant> _variantsForSearch(
    String query, {
    required bool thorough,
  }) {
    final all = GeocodingQueryNormalizer.buildVariants(query);
    if (thorough) {
      return all;
    }
    if (GeocodingQueryNormalizer.parseStructuredParts(query) != null) {
      return all.take(2).toList(growable: false);
    }
    return all.take(1).toList(growable: false);
  }

  @override
  Future<GeocodingPlace?> reverse(GeoPoint location) async {
    final uri = Uri.parse(
      '${NavigationConstants.nominatimBaseUrl}/reverse',
    ).replace(
      queryParameters: {
        'lat': location.lat.toString(),
        'lon': location.lng.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'accept-language': 'es',
        'zoom': '18',
      },
    );

    final response = await _rateLimiter.run(
      () => _getWithRetry(uri),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return null;
    }
    return _parsePlace(body);
  }

  Future<List<GeocodingPlace>> _fetchVariant(
    GeocodingSearchVariant variant, {
    GeoPoint? near,
  }) async {
    final params = <String, String>{
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'accept-language': 'es',
      'countrycodes': 'es',
    };

    switch (variant) {
      case GeocodingFreeTextVariant(:final query):
        if (query.length < 3) {
          return const [];
        }
        params['q'] = query;
      case GeocodingStructuredVariant(:final street, :final city):
        params['street'] = street;
        params['city'] = city;
        params['country'] = 'España';
    }

    if (near != null) {
      params['lat'] = near.lat.toString();
      params['lon'] = near.lng.toString();
      const delta = 0.35;
      params['viewbox'] = [
        near.lng - delta,
        near.lat + delta,
        near.lng + delta,
        near.lat - delta,
      ].map((value) => value.toStringAsFixed(5)).join(',');
    }

    final uri = Uri.parse(
      '${NavigationConstants.nominatimBaseUrl}/search',
    ).replace(queryParameters: params);

    final response = await _rateLimiter.run(
      () => _getWithRetry(uri),
    );

    if (response.statusCode != 200) {
      throw const NavigationException(
        'No se pudo buscar la dirección. Inténtalo de nuevo.',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! List<dynamic>) {
      return const [];
    }

    return body
        .whereType<Map<String, dynamic>>()
        .map(_parsePlace)
        .whereType<GeocodingPlace>()
        .toList(growable: false);
  }

  Future<http.Response> _getWithRetry(Uri uri, {int retries = 1}) async {
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': NavigationConstants.geocodingUserAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 429 && retries > 0) {
      await Future<void>.delayed(
        NavigationConstants.geocodingMinRequestInterval * 2,
      );
      return _getWithRetry(uri, retries: retries - 1);
    }
    if (response.statusCode == 429) {
      throw const NavigationException(
        'Demasiadas búsquedas. Espera unos segundos e inténtalo otra vez.',
      );
    }
    return response;
  }

  GeocodingPlace? _parsePlace(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lng = double.tryParse('${json['lon']}');
    final displayName = json['display_name'] as String?;
    if (lat == null || lng == null || displayName == null) {
      return null;
    }
    final address = json['address'] as Map<String, dynamic>?;
    final category = '${json['category'] ?? ''}';
    final type = '${json['type'] ?? ''}';
    return GeocodingPlace(
      displayName: displayName,
      location: GeoPoint(lat: lat, lng: lng),
      shortLabel: _primaryLabel(address, displayName),
      secondaryLabel: _secondaryLabel(address, displayName),
      category: category,
      osmType: type,
      houseNumber: address?['house_number']?.toString(),
    );
  }

  String _primaryLabel(Map<String, dynamic>? address, String displayName) {
    if (address != null) {
      final road = address['road'] as String?;
      final number = address['house_number'] as String?;
      if (road != null && road.isNotEmpty) {
        return number == null || number.isEmpty ? road : '$road, $number';
      }
      final name = address['name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return displayName.split(',').first.trim();
  }

  String? _secondaryLabel(Map<String, dynamic>? address, String displayName) {
    if (address != null) {
      final parts = <String>[
        if (address['suburb'] case final String suburb when suburb.isNotEmpty)
          suburb,
        if (address['neighbourhood']
            case final String neighbourhood when neighbourhood.isNotEmpty)
          neighbourhood,
        if (address['city'] case final String city when city.isNotEmpty) city,
        if (address['town'] case final String town when town.isNotEmpty) town,
        if (address['village'] case final String village when village.isNotEmpty)
          village,
        if (address['state'] case final String state when state.isNotEmpty)
          state,
      ];
      if (parts.isNotEmpty) {
        return parts.take(3).join(', ');
      }
    }
    final segments = displayName.split(',').map((part) => part.trim()).toList();
    if (segments.length <= 1) {
      return null;
    }
    return segments.sublist(1, segments.length.clamp(1, 4)).join(', ');
  }
}
