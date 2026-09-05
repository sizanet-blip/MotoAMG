import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/data/helpers/geocoding_query_normalizer.dart';

void main() {
  group('GeocodingQueryNormalizer', () {
    test('corrige "lle" truncado al inicio', () {
      expect(
        GeocodingQueryNormalizer.normalizeFreeText(
          'lle prevision social, 9, zaragoza',
        ),
        'calle prevision social 9 zaragoza',
      );
    });

    test('parsea calle, número y ciudad con comas', () {
      final parts = GeocodingQueryNormalizer.parseStructuredParts(
        'Calle Previsión Social, 9, Zaragoza',
      );

      expect(parts?.street, 'Calle Previsión Social 9');
      expect(parts?.city, 'Zaragoza');
    });

    test('parsea calle, número y ciudad sin comas', () {
      final parts = GeocodingQueryNormalizer.parseStructuredParts(
        'paseo de los arcos 22, siguenza',
      );

      expect(parts?.street, 'paseo de los arcos 22');
      expect(parts?.city, 'Sigüenza');
    });

    test('extrae número de portal', () {
      expect(
        GeocodingQueryNormalizer.extractHouseNumber(
          'paseo de los arcos 22, siguenza',
        ),
        '22',
      );
    });

    test('genera variantes estructuradas con número', () {
      final variants = GeocodingQueryNormalizer.buildVariants(
        'paseo de los arcos 22, siguenza',
      );

      expect(variants, isNotEmpty);
      expect(
        variants.whereType<GeocodingStructuredVariant>().first.street,
        '22, paseo de los arcos',
      );
      expect(
        variants.whereType<GeocodingStructuredVariant>().first.city,
        'Sigüenza',
      );
    });
  });
}
