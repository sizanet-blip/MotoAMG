import 'package:equatable/equatable.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

/// Punto de un itinerario (origen, parada o destino).
class RouteItineraryStop extends Equatable {
  const RouteItineraryStop({
    required this.id,
    required this.label,
    required this.point,
    this.followsGps = false,
  });

  final String id;
  final String label;
  final GeoPoint point;

  /// Origen que se actualiza con el GPS.
  final bool followsGps;

  RouteItineraryStop copyWith({
    String? label,
    GeoPoint? point,
    bool? followsGps,
  }) {
    return RouteItineraryStop(
      id: id,
      label: label ?? this.label,
      point: point ?? this.point,
      followsGps: followsGps ?? this.followsGps,
    );
  }

  @override
  List<Object?> get props => [id, label, point, followsGps];
}

/// Itinerario ordenado: índice 0 = origen; el último = destino final.
class RouteItinerary extends Equatable {
  const RouteItinerary({this.stops = const []});

  final List<RouteItineraryStop> stops;

  bool get hasOrigin => stops.isNotEmpty;
  bool get canPlan => stops.length >= 2;
  bool get hasIntermediateStops => stops.length > 2;

  RouteItineraryStop? get origin => stops.isEmpty ? null : stops.first;
  RouteItineraryStop? get destination =>
      stops.length < 2 ? null : stops.last;

  List<RouteItineraryStop> get intermediateStops {
    if (stops.length <= 2) {
      return const [];
    }
    return stops.sublist(1, stops.length - 1);
  }

  RouteItinerary copyWithStops(List<RouteItineraryStop> next) {
    return RouteItinerary(stops: List.unmodifiable(next));
  }

  @override
  List<Object?> get props => [stops];
}
