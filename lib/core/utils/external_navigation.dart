import 'package:flutter/foundation.dart';
import 'package:moto_amg/features/navigation/domain/entities/geo_point.dart';

/// Enlaces para abrir Waze o Google Maps con un destino.
abstract final class ExternalNavigation {
  static Uri wazeTo(GeoPoint point) => Uri.parse(
        'https://waze.com/ul?ll=${point.lat},${point.lng}&navigate=yes',
      );

  static Uri googleMapsNavigationTo(GeoPoint point) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(
        'comgooglemaps://?daddr=${point.lat},${point.lng}&directionsmode=driving',
      );
    }
    return Uri.parse(
      'google.navigation:q=${point.lat},${point.lng}',
    );
  }

  static Uri googleMapsWebTo(GeoPoint point) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${point.lat},${point.lng}&travelmode=driving',
      );
}
