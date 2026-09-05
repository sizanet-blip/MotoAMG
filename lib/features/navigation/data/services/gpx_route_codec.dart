import 'dart:math' as math;

import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';

/// Parada leída de un GPX (nombre opcional).
class GpxImportedStop {
  const GpxImportedStop({required this.point, this.name});

  final GeoPoint point;
  final String? name;

  String get label {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';
  }
}

/// Codifica / decodifica rutas MotoAMG en GPX 1.1 (sin dependencia XML).
class GpxRouteCodec {
  const GpxRouteCodec();

  /// Exporta waypoints (origen + paradas + destino) y la polilínea como track.
  String encode(
    NavigationRoute route, {
    String name = 'Ruta MotoAMG',
  }) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="MotoAMG" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>${_escape(name)}</name>')
      ..writeln('  </metadata>');

    _writeWpt(
      buffer,
      route.origin,
      route.originLabel?.trim().isNotEmpty == true
          ? route.originLabel!.trim()
          : 'Origen',
    );
    for (var i = 0; i < route.waypoints.length; i++) {
      _writeWpt(buffer, route.waypoints[i], 'Parada ${i + 1}');
    }
    _writeWpt(
      buffer,
      route.destination,
      route.destinationLabel?.trim().isNotEmpty == true
          ? route.destinationLabel!.trim()
          : 'Destino',
    );

    buffer
      ..writeln('  <trk>')
      ..writeln('    <name>${_escape(name)}</name>')
      ..writeln('    <trkseg>');
    for (final point in route.polyline) {
      buffer.writeln(
        '      <trkpt lat="${point.lat}" lon="${point.lng}"></trkpt>',
      );
    }
    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return buffer.toString();
  }

  /// Devuelve paradas ordenadas para el itinerario (≥2 o lista vacía).
  ///
  /// Prioridad: `rtept` → `wpt` (≥2) → extremos del primer `trk`.
  /// Trazos densos (muchos puntos cercanos) se reducen a origen + destino
  /// para que Valhalla recalcule y la UI no se llene de “paradas” falsas.
  List<GpxImportedStop> decode(String xml) {
    final rte = _parsePoints(xml, 'rtept');
    if (rte.length >= 2) {
      return _forItinerary(rte);
    }
    final wpts = _parsePoints(xml, 'wpt');
    if (wpts.length >= 2) {
      return _forItinerary(wpts);
    }
    final track = _parsePoints(xml, 'trkpt');
    if (track.length >= 2) {
      return [track.first, track.last];
    }
    return const [];
  }

  /// Máximo origen + 3 vias + destino si las paradas parecen reales.
  static const _maxItineraryStops = 5;

  List<GpxImportedStop> _forItinerary(List<GpxImportedStop> stops) {
    if (stops.length <= 2) {
      return stops;
    }
    if (_averageSpacingMeters(stops) < 2000) {
      return [stops.first, stops.last];
    }
    if (stops.length <= _maxItineraryStops) {
      return stops;
    }
    final middles = stops.sublist(1, stops.length - 1);
    final keep = _maxItineraryStops - 2;
    final step = middles.length / keep;
    return [
      stops.first,
      for (var i = 0; i < keep; i++) middles[(i * step).floor().clamp(0, middles.length - 1)],
      stops.last,
    ];
  }

  double _averageSpacingMeters(List<GpxImportedStop> stops) {
    if (stops.length < 2) {
      return 0;
    }
    var total = 0.0;
    for (var i = 1; i < stops.length; i++) {
      total += _approxMeters(stops[i - 1].point, stops[i].point);
    }
    return total / (stops.length - 1);
  }

  double _approxMeters(GeoPoint a, GeoPoint b) {
    const metersPerDeg = 111320.0;
    final dLat = (a.lat - b.lat) * metersPerDeg;
    final dLng = (a.lng - b.lng) *
        metersPerDeg *
        math.cos(a.lat * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  void _writeWpt(StringBuffer buffer, GeoPoint point, String name) {
    buffer
      ..writeln('  <wpt lat="${point.lat}" lon="${point.lng}">')
      ..writeln('    <name>${_escape(name)}</name>')
      ..writeln('  </wpt>');
  }

  List<GpxImportedStop> _parsePoints(String xml, String tag) {
    final pattern = RegExp(
      '<$tag\\s+([^>]+)>([\\s\\S]*?)</$tag>|<$tag\\s+([^>]+)/?>',
      caseSensitive: false,
    );
    final namePattern = RegExp(
      '<name>([\\s\\S]*?)</name>',
      caseSensitive: false,
    );
    final latPattern = RegExp(r'''lat\s*=\s*["']([^"']+)["']''');
    final lonPattern = RegExp(r'''lon\s*=\s*["']([^"']+)["']''');

    final stops = <GpxImportedStop>[];
    for (final match in pattern.allMatches(xml)) {
      final attrs = match.group(1) ?? match.group(3) ?? '';
      final body = match.group(2) ?? '';
      final latRaw = latPattern.firstMatch(attrs)?.group(1);
      final lonRaw = lonPattern.firstMatch(attrs)?.group(1);
      if (latRaw == null || lonRaw == null) {
        continue;
      }
      final lat = double.tryParse(latRaw);
      final lng = double.tryParse(lonRaw);
      if (lat == null || lng == null) {
        continue;
      }
      final nameRaw = namePattern.firstMatch(body)?.group(1);
      stops.add(
        GpxImportedStop(
          point: GeoPoint(lat: lat, lng: lng),
          name: nameRaw == null ? null : _unescape(nameRaw.trim()),
        ),
      );
    }
    return stops;
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _unescape(String value) => value
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&amp;', '&');
}
