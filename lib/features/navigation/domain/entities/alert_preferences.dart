import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:loc_motos/core/constants/navigation_constants.dart';
import 'package:loc_motos/features/navigation/domain/entities/route_alert.dart';

/// Preferencias de avisos en navegación (HUD, mapa y voz).
class AlertPreferences extends Equatable {
  const AlertPreferences({
    this.radarsEnabled = true,
    this.radarShowOnMap = true,
    this.radarVoiceEnabled = true,
    this.radarAnnounceDistances = defaultRadarAnnounceDistances,
    this.fuelEnabled = true,
    this.fuelShowOnMap = true,
    this.fuelShowPrice = true,
    this.fuelVoiceEnabled = false,
    this.fuelAnnounceMeters = NavigationConstants.fuelAnnounceMeters,
    this.tollsEnabled = true,
    this.tollShowOnMap = true,
    this.tollVoiceEnabled = true,
    this.tollAnnounceMeters = NavigationConstants.tollAnnounceMeters,
    this.curvesEnabled = true,
    this.curvesShowOnMap = false,
    this.curvesVoiceEnabled = false,
  });

  static const defaults = AlertPreferences();

  /// Por defecto: aviso medio + aviso fuerte (comportamiento anterior).
  static const defaultRadarAnnounceDistances = <double>[350, 90];

  final bool radarsEnabled;
  final bool radarShowOnMap;
  final bool radarVoiceEnabled;

  /// Distancias de aviso de radar (varias). Orden interno: mayor → menor.
  final List<double> radarAnnounceDistances;

  final bool fuelEnabled;
  final bool fuelShowOnMap;
  final bool fuelShowPrice;
  final bool fuelVoiceEnabled;
  final double fuelAnnounceMeters;

  final bool tollsEnabled;
  final bool tollShowOnMap;
  final bool tollVoiceEnabled;
  final double tollAnnounceMeters;

  final bool curvesEnabled;
  final bool curvesShowOnMap;
  final bool curvesVoiceEnabled;

  /// Opciones de distancia para la UI.
  static const radarAnnounceOptions = <double>[800, 500, 350, 200, 150, 90, 50];
  static const fuelAnnounceOptions = <double>[500, 800, 1200, 2000];
  static const tollAnnounceOptions = <double>[400, 800, 1200];

  /// Distancia máxima: cuándo mostrar el banner HUD.
  double get radarHudMeters {
    if (radarAnnounceDistances.isEmpty) {
      return NavigationConstants.alertAnnounceMeters;
    }
    return radarAnnounceDistances.reduce(math.max);
  }

  /// Distancia mínima: aviso de voz “fuerte” / inminente.
  double get radarImminentMeters {
    if (radarAnnounceDistances.isEmpty) {
      return NavigationConstants.radarImminentAnnounceMeters;
    }
    return radarAnnounceDistances.reduce(math.min);
  }

  /// Umbrales ordenados de lejos a cerca.
  List<double> get radarThresholdsDescending {
    final list = List<double>.from(
      radarAnnounceDistances.isEmpty
          ? defaultRadarAnnounceDistances
          : radarAnnounceDistances,
    )..sort((a, b) => b.compareTo(a));
    return list;
  }

  bool isTypeEnabled(RouteAlertType type) => switch (type) {
        RouteAlertType.speedCamera => radarsEnabled,
        RouteAlertType.fuel => fuelEnabled,
        RouteAlertType.toll => tollsEnabled,
        RouteAlertType.sharpCurve => curvesEnabled,
      };

  bool showTypeOnMap(RouteAlertType type) {
    if (!isTypeEnabled(type)) {
      return false;
    }
    return switch (type) {
      RouteAlertType.speedCamera => radarShowOnMap,
      RouteAlertType.fuel => fuelShowOnMap,
      RouteAlertType.toll => tollShowOnMap,
      RouteAlertType.sharpCurve => curvesShowOnMap,
    };
  }

  bool voiceEnabledFor(RouteAlertType type) {
    if (!isTypeEnabled(type)) {
      return false;
    }
    return switch (type) {
      RouteAlertType.speedCamera => radarVoiceEnabled,
      RouteAlertType.fuel => fuelVoiceEnabled,
      RouteAlertType.toll => tollVoiceEnabled,
      RouteAlertType.sharpCurve => curvesVoiceEnabled,
    };
  }

  double announceMetersFor(RouteAlertType type) => switch (type) {
        RouteAlertType.speedCamera => radarHudMeters,
        RouteAlertType.fuel => fuelAnnounceMeters,
        RouteAlertType.toll => tollAnnounceMeters,
        RouteAlertType.sharpCurve => radarHudMeters,
      };

  String get enrichCacheSuffix => [
        radarsEnabled ? '1' : '0',
        fuelEnabled ? '1' : '0',
        tollsEnabled ? '1' : '0',
        curvesEnabled ? '1' : '0',
        fuelShowPrice ? '1' : '0',
      ].join();

  static List<double> _normalizeDistances(Iterable<double> raw) {
    final unique = <double>{};
    for (final m in raw) {
      if (m > 0) {
        unique.add(m);
      }
    }
    if (unique.isEmpty) {
      return List<double>.from(defaultRadarAnnounceDistances);
    }
    final list = unique.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  AlertPreferences copyWith({
    bool? radarsEnabled,
    bool? radarShowOnMap,
    bool? radarVoiceEnabled,
    List<double>? radarAnnounceDistances,
    bool? fuelEnabled,
    bool? fuelShowOnMap,
    bool? fuelShowPrice,
    bool? fuelVoiceEnabled,
    double? fuelAnnounceMeters,
    bool? tollsEnabled,
    bool? tollShowOnMap,
    bool? tollVoiceEnabled,
    double? tollAnnounceMeters,
    bool? curvesEnabled,
    bool? curvesShowOnMap,
    bool? curvesVoiceEnabled,
  }) {
    return AlertPreferences(
      radarsEnabled: radarsEnabled ?? this.radarsEnabled,
      radarShowOnMap: radarShowOnMap ?? this.radarShowOnMap,
      radarVoiceEnabled: radarVoiceEnabled ?? this.radarVoiceEnabled,
      radarAnnounceDistances: radarAnnounceDistances != null
          ? _normalizeDistances(radarAnnounceDistances)
          : this.radarAnnounceDistances,
      fuelEnabled: fuelEnabled ?? this.fuelEnabled,
      fuelShowOnMap: fuelShowOnMap ?? this.fuelShowOnMap,
      fuelShowPrice: fuelShowPrice ?? this.fuelShowPrice,
      fuelVoiceEnabled: fuelVoiceEnabled ?? this.fuelVoiceEnabled,
      fuelAnnounceMeters: fuelAnnounceMeters ?? this.fuelAnnounceMeters,
      tollsEnabled: tollsEnabled ?? this.tollsEnabled,
      tollShowOnMap: tollShowOnMap ?? this.tollShowOnMap,
      tollVoiceEnabled: tollVoiceEnabled ?? this.tollVoiceEnabled,
      tollAnnounceMeters: tollAnnounceMeters ?? this.tollAnnounceMeters,
      curvesEnabled: curvesEnabled ?? this.curvesEnabled,
      curvesShowOnMap: curvesShowOnMap ?? this.curvesShowOnMap,
      curvesVoiceEnabled: curvesVoiceEnabled ?? this.curvesVoiceEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'radarsEnabled': radarsEnabled,
        'radarShowOnMap': radarShowOnMap,
        'radarVoiceEnabled': radarVoiceEnabled,
        'radarAnnounceDistances': radarAnnounceDistances,
        'fuelEnabled': fuelEnabled,
        'fuelShowOnMap': fuelShowOnMap,
        'fuelShowPrice': fuelShowPrice,
        'fuelVoiceEnabled': fuelVoiceEnabled,
        'fuelAnnounceMeters': fuelAnnounceMeters,
        'tollsEnabled': tollsEnabled,
        'tollShowOnMap': tollShowOnMap,
        'tollVoiceEnabled': tollVoiceEnabled,
        'tollAnnounceMeters': tollAnnounceMeters,
        'curvesEnabled': curvesEnabled,
        'curvesShowOnMap': curvesShowOnMap,
        'curvesVoiceEnabled': curvesVoiceEnabled,
      };

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    double meters(String key, double fallback) {
      final v = json[key];
      if (v is num) {
        return v.toDouble();
      }
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final v = json[key];
      if (v is bool) {
        return v;
      }
      return fallback;
    }

    List<double> distances;
    final rawList = json['radarAnnounceDistances'];
    if (rawList is List && rawList.isNotEmpty) {
      distances = _normalizeDistances([
        for (final item in rawList)
          if (item is num) item.toDouble(),
      ]);
    } else {
      // Migración desde campos únicos anteriores.
      final announce = meters(
        'radarAnnounceMeters',
        NavigationConstants.alertAnnounceMeters,
      );
      var imminent = meters(
        'radarImminentMeters',
        NavigationConstants.radarImminentAnnounceMeters,
      );
      if (imminent >= announce) {
        imminent = (announce * 0.35).clamp(30, announce - 10);
      }
      distances = _normalizeDistances([announce, imminent]);
    }

    return AlertPreferences(
      radarsEnabled: flag('radarsEnabled', true),
      radarShowOnMap: flag('radarShowOnMap', true),
      radarVoiceEnabled: flag('radarVoiceEnabled', true),
      radarAnnounceDistances: distances,
      fuelEnabled: flag('fuelEnabled', true),
      fuelShowOnMap: flag('fuelShowOnMap', true),
      fuelShowPrice: flag('fuelShowPrice', true),
      fuelVoiceEnabled: flag('fuelVoiceEnabled', false),
      fuelAnnounceMeters: meters(
        'fuelAnnounceMeters',
        NavigationConstants.fuelAnnounceMeters,
      ),
      tollsEnabled: flag('tollsEnabled', true),
      tollShowOnMap: flag('tollShowOnMap', true),
      tollVoiceEnabled: flag('tollVoiceEnabled', true),
      tollAnnounceMeters: meters(
        'tollAnnounceMeters',
        NavigationConstants.tollAnnounceMeters,
      ),
      curvesEnabled: flag('curvesEnabled', true),
      curvesShowOnMap: flag('curvesShowOnMap', false),
      curvesVoiceEnabled: flag('curvesVoiceEnabled', false),
    );
  }

  @override
  List<Object?> get props => [
        radarsEnabled,
        radarShowOnMap,
        radarVoiceEnabled,
        radarAnnounceDistances,
        fuelEnabled,
        fuelShowOnMap,
        fuelShowPrice,
        fuelVoiceEnabled,
        fuelAnnounceMeters,
        tollsEnabled,
        tollShowOnMap,
        tollVoiceEnabled,
        tollAnnounceMeters,
        curvesEnabled,
        curvesShowOnMap,
        curvesVoiceEnabled,
      ];
}

String formatAlertDistanceMeters(double meters) {
  if (meters >= 1000) {
    final km = meters / 1000;
    final text = km == km.roundToDouble()
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1).replaceAll('.', ',');
    return '$text km';
  }
  return '${meters.round()} m';
}
