import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// Una línea de precio (grado + importe).
class FuelPriceLine {
  const FuelPriceLine({
    required this.grade,
    required this.priceText,
  });

  final String grade;
  final String priceText;
}

/// Partes legibles de un aviso de gasolinera (marca + precios).
class FuelAlertParts {
  const FuelAlertParts({
    required this.brand,
    this.prices = const [],
  });

  final String brand;
  final List<FuelPriceLine> prices;

  bool get hasPrice => prices.isNotEmpty;

  /// Compat: primer grado (UI antigua / voz corta).
  String? get grade => prices.isEmpty ? null : prices.first.grade;

  /// Compat: primer precio.
  String? get priceText => prices.isEmpty ? null : prices.first.priceText;
}

final _gradePriceRe = RegExp(
  r'^(95|98|Gasóleo|G\.Prem|G\.B)\s+([\d.,]+\s*€)',
  caseSensitive: false,
);

/// Extrae marca y todos los precios desde [RouteAlert.label] (+ meta).
FuelAlertParts parseFuelAlertParts(RouteAlert alert) {
  final lines = alert.label
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final brandFromLabel =
      lines.isNotEmpty && lines.first.trim().isNotEmpty ? lines.first.trim() : null;
  final brandFromMeta =
      alert.meta != null && alert.meta!.trim().isNotEmpty
          ? alert.meta!.trim()
          : null;
  final brand = brandFromLabel ?? brandFromMeta ?? 'Gasolinera';

  if (lines.length < 2) {
    return FuelAlertParts(brand: brand);
  }

  final prices = <FuelPriceLine>[];
  for (final line in lines.skip(1)) {
    // Formato actual: una línea por combustible.
    final direct = _gradePriceRe.firstMatch(line);
    if (direct != null) {
      prices.add(
        FuelPriceLine(
          grade: direct.group(1)!,
          priceText: direct.group(2)!.trim(),
        ),
      );
      continue;
    }
    // Formato antiguo: "95 1,80 € · 98 1,95 €" en una sola línea.
    for (final chunk in line.split(' · ')) {
      final m = _gradePriceRe.firstMatch(chunk.trim());
      if (m != null) {
        prices.add(
          FuelPriceLine(
            grade: m.group(1)!,
            priceText: m.group(2)!.trim(),
          ),
        );
      }
    }
  }

  if (prices.isEmpty) {
    final fallback = lines.sublist(1).join(' · ');
    return FuelAlertParts(
      brand: brand,
      prices: [
        FuelPriceLine(grade: '', priceText: fallback),
      ],
    );
  }

  return FuelAlertParts(brand: brand, prices: prices);
}
