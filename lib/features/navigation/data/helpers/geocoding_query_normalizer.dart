/// Normaliza consultas de dirección para Nominatim (OSM).
abstract final class GeocodingQueryNormalizer {
  static final _houseNumberPattern = RegExp(
    r'(?:^|\s|,)(\d+\w?)(?:\s|,|$)',
    caseSensitive: false,
  );

  /// Texto libre listo para `q=`: espacios, comas y typos frecuentes.
  static String normalizeFreeText(String query) {
    var text = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) {
      return text;
    }

    text = text.replaceAll(RegExp(r'\s*,\s*'), ' ');
    text = _expandTruncatedStreetPrefix(text);
    text = _fixCityAccents(text);
    return text.trim();
  }

  /// Número de portal detectado en la consulta del usuario, si lo hay.
  static String? extractHouseNumber(String query) {
    final structured = parseStructuredParts(query);
    if (structured != null) {
      final match = RegExp(r'\b(\d+\w?)\s*$').firstMatch(structured.street);
      if (match != null) {
        return match.group(1);
      }
    }

    final free = normalizeFreeText(query);
    final matches = _houseNumberPattern.allMatches(free).toList();
    if (matches.isEmpty) {
      return null;
    }
    return matches.last.group(1);
  }

  /// Partes estructuradas (`street` + `city`) si se puede inferir.
  static ({String street, String city})? parseStructuredParts(String query) {
    final parts = query
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length >= 2) {
      final city = _fixCityAccents(parts.last);
      final beforeCity = parts.sublist(0, parts.length - 1);

      String street;
      if (beforeCity.length >= 2 &&
          RegExp(r'^\d+\w?$').hasMatch(beforeCity.last)) {
        final number = beforeCity.last;
        final name = beforeCity.sublist(0, beforeCity.length - 1).join(' ');
        street = '$name $number'.trim();
      } else {
        street = beforeCity.join(' ');
      }

      street = _expandTruncatedStreetPrefix(street);
      if (street.isEmpty || city.isEmpty) {
        return null;
      }
      return (street: street, city: city);
    }

    return _parseFreeTextStreetAndCity(query);
  }

  /// Variantes de búsqueda, de más específica a más permisiva.
  static List<GeocodingSearchVariant> buildVariants(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return const [];
    }

    final variants = <GeocodingSearchVariant>[];
    void add(GeocodingSearchVariant variant) {
      if (variants.any((existing) => existing.key == variant.key)) {
        return;
      }
      variants.add(variant);
    }

    final structured = parseStructuredParts(trimmed);
    if (structured != null) {
      // Nominatim structured suele ir mejor con "número, calle".
      final house = RegExp(r'\b(\d+\w?)\s*$').firstMatch(structured.street);
      if (house != null) {
        final number = house.group(1)!;
        final road = structured.street
            .substring(0, house.start)
            .trim()
            .replaceAll(RegExp(r'[,\s]+$'), '');
        if (road.isNotEmpty) {
          add(
            GeocodingStructuredVariant(
              street: '$number, $road',
              city: structured.city,
            ),
          );
          add(
            GeocodingStructuredVariant(
              street: '$road $number',
              city: structured.city,
            ),
          );
        }
      } else {
        add(
          GeocodingStructuredVariant(
            street: structured.street,
            city: structured.city,
          ),
        );
      }
      add(
        GeocodingFreeTextVariant(
          '${structured.street} ${structured.city}'.trim(),
        ),
      );
    }

    final freeText = normalizeFreeText(trimmed);
    add(GeocodingFreeTextVariant(freeText));

    final compact = trimmed.replaceAll(RegExp(r'\s*,\s*|\s+'), ' ').trim();
    if (compact != freeText) {
      add(GeocodingFreeTextVariant(_expandTruncatedStreetPrefix(compact)));
    }

    return variants;
  }

  static ({String street, String city})? _parseFreeTextStreetAndCity(
    String query,
  ) {
    final free = normalizeFreeText(query);
    final tokens = free.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.length < 3) {
      return null;
    }

    // "... 22 siguenza" → street + número + ciudad
    final last = tokens.last;
    final maybeNumber = tokens[tokens.length - 2];
    if (RegExp(r'^\d+\w?$').hasMatch(maybeNumber) &&
        !RegExp(r'^\d+\w?$').hasMatch(last)) {
      final road = tokens.sublist(0, tokens.length - 2).join(' ');
      if (road.isEmpty) {
        return null;
      }
      return (street: '$road $maybeNumber', city: _fixCityAccents(last));
    }

    return null;
  }

  static String _expandTruncatedStreetPrefix(String text) {
    final match = RegExp(r'^lle\b', caseSensitive: false).firstMatch(text);
    if (match != null) {
      return 'calle ${text.substring(match.end).trimLeft()}';
    }
    return text;
  }

  static String _fixCityAccents(String city) {
    final lower = city.toLowerCase();
    const fixes = <String, String>{
      'siguenza': 'Sigüenza',
      'zaragoza': 'Zaragoza',
      'madrid': 'Madrid',
      'barcelona': 'Barcelona',
      'valencia': 'Valencia',
      'sevilla': 'Sevilla',
    };
    return fixes[lower] ?? city;
  }
}

sealed class GeocodingSearchVariant {
  const GeocodingSearchVariant();

  String get key;
}

final class GeocodingFreeTextVariant extends GeocodingSearchVariant {
  const GeocodingFreeTextVariant(this.query);

  final String query;

  @override
  String get key => 'q:$query';
}

final class GeocodingStructuredVariant extends GeocodingSearchVariant {
  const GeocodingStructuredVariant({required this.street, required this.city});

  final String street;
  final String city;

  @override
  String get key => 's:$street|$city';
}
