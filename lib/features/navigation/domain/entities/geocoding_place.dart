import 'package:equatable/equatable.dart';
import 'package:loc_motos/features/navigation/domain/entities/geo_point.dart';

/// Resultado de búsqueda / geocodificación de una dirección.
class GeocodingPlace extends Equatable {
  const GeocodingPlace({
    required this.displayName,
    required this.location,
    this.shortLabel,
    this.secondaryLabel,
    this.category,
    this.osmType,
    this.houseNumber,
    this.isApproximateHouseNumber = false,
  });

  final String displayName;
  final GeoPoint location;

  /// Línea principal (calle y número, o nombre del sitio).
  final String? shortLabel;

  /// Contexto (barrio, ciudad, provincia) sin repetir la calle.
  final String? secondaryLabel;

  /// Categoría/tipo OSM (p. ej. highway/residential) para ordenar resultados.
  final String? category;
  final String? osmType;
  final String? houseNumber;

  /// True si el número lo escribió el usuario pero OSM solo tenía la calle.
  final bool isApproximateHouseNumber;

  String get primaryLine => shortLabel ?? displayName.split(',').first.trim();

  /// Etiqueta legible para mostrar en el campo tras confirmar.
  String get displayLine {
    final context = contextLine;
    final base = context == null ? primaryLine : '$primaryLine · $context';
    if (!isApproximateHouseNumber) {
      return base;
    }
    return '$base (aprox.)';
  }

  String? get contextLine {
    final secondary = secondaryLabel?.trim();
    if (secondary == null || secondary.isEmpty) {
      return null;
    }
    if (secondary.toLowerCase() == primaryLine.toLowerCase()) {
      return null;
    }
    return secondary;
  }

  @override
  List<Object?> get props => [
    displayName,
    location,
    shortLabel,
    secondaryLabel,
    category,
    osmType,
    houseNumber,
    isApproximateHouseNumber,
  ];
}
