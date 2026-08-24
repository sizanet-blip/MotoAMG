import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/data/datasources/geocoding_remote_datasource.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_query_normalizer.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_result_processor.dart';
import 'package:loc_motos/features/navigation/data/helpers/geocoding_search_cache.dart';
import 'package:loc_motos/features/navigation/data/helpers/photon_geocoding_parser.dart';
import 'package:loc_motos/features/navigation/domain/entities/geocoding_place.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';
import 'package:loc_motos/features/navigation/domain/exceptions/navigation_exceptions.dart';

/// Buscador Photon (Komoot) — rápido y pensado para autocomplete.
class PhotonGeocodingDataSource implements GeocodingRemoteDataSource {
  PhotonGeocodingDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = GeocodingSearchCache('photon');

  bool get isConfigured => NavigationConstants.photonBaseUrl.isNotEmpty;

  @override
  Future<List<GeocodingPlace>> search(
    String query, {
    GeoPoint? near,
    bool thorough = false,
  }) async {
    if (!isConfigured) {
      throw const NavigationException('Servidor Photon no configurado.');
    }

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
    final queries = _queriesForSearch(trimmed, thorough: thorough);

    List<GeocodingPlace> best = const [];
    for (final q in queries) {
      final results = await _fetchQuery(q, near: near);
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

  @override
  Future<GeocodingPlace?> reverse(GeoPoint location) async {
    if (!isConfigured) {
      return null;
    }

    final uri = Uri.parse('${NavigationConstants.photonBaseUrl}/reverse')
        .replace(
      queryParameters: {
        'lat': location.lat.toString(),
        'lon': location.lng.toString(),
        'lang': NavigationConstants.photonLanguage,
      },
    );

    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return null;
    }

    final features = body['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) {
      return null;
    }
    return PhotonGeocodingParser.parseFeature(
      features.first as Map<String, dynamic>,
    );
  }

  List<String> _queriesForSearch(String query, {required bool thorough}) {
    final variants = GeocodingQueryNormalizer.buildVariants(query);
    final queries = <String>[];
    for (final variant in variants) {
      final q = switch (variant) {
        GeocodingFreeTextVariant(:final query) => query,
        GeocodingStructuredVariant(:final street, :final city) =>
          '$street, $city, España',
      };
      if (q.length >= 3 && !queries.contains(q)) {
        queries.add(q);
      }
    }
    if (thorough) {
      return queries;
    }
    if (GeocodingQueryNormalizer.parseStructuredParts(query) != null) {
      return queries.take(2).toList(growable: false);
    }
    return queries.take(1).toList(growable: false);
  }

  Future<List<GeocodingPlace>> _fetchQuery(
    String query, {
    GeoPoint? near,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': '8',
      'lang': NavigationConstants.photonLanguage,
    };
    if (near != null) {
      params['lat'] = near.lat.toString();
      params['lon'] = near.lng.toString();
    }

    final uri = Uri.parse('${NavigationConstants.photonBaseUrl}/api')
        .replace(queryParameters: params);

    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw NavigationException(
        'Photon respondió ${response.statusCode}.',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return const [];
    }

    final features = body['features'] as List<dynamic>? ?? const [];
    return features
        .whereType<Map<String, dynamic>>()
        .map(PhotonGeocodingParser.parseFeature)
        .whereType<GeocodingPlace>()
        .toList(growable: false);
  }
}
