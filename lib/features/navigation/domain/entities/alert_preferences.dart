import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_map_poi.dart';

/// Preferencias de avisos en navegación (HUD, mapa y voz).
class AlertPreferences extends Equatable {
  const AlertPreferences({
    this.radarsEnabled = true,
    this.radarShowOnMap = true,
    this.radarShowOnPreview = false,
    this.radarVoiceEnabled = true,
    this.radarAnnounceDistances = defaultRadarAnnounceDistances,
    this.fuelEnabled = true,
    this.fuelShowOnMap = true,
    this.fuelShowOnPreview = false,
    this.fuelShowPrice = true,
    this.fuelPriceFilterEnabled = false,
    this.fuelMaxPriceEur,
    this.fuelVoiceEnabled = false,
    this.fuelAnnounceMeters = NavigationConstants.fuelAnnounceMeters,
    this.tollsEnabled = true,
    this.tollShowOnMap = true,
    this.tollShowOnPreview = false,
    this.tollVoiceEnabled = true,
    this.tollAnnounceMeters = NavigationConstants.tollAnnounceMeters,
    this.curvesEnabled = true,
    this.curvesShowOnMap = false,
    this.curvesShowOnPreview = false,
    this.curvesVoiceEnabled = false,
    this.curveOpenEnabled = false,
    this.curvePronouncedEnabled = false,
    this.curveTightEnabled = true,
    this.curveVeryClosedEnabled = true,
    this.speedLimitAlertEnabled = true,
    this.speedLimitToleranceKmh = 5,
    this.speedLimitSoundEnabled = true,
    this.trafficSignsEnabled = true,
    this.trafficSignalShowOnMap = true,
    this.stopShowOnMap = true,
    this.giveWayShowOnMap = true,
  });

  static const defaults = AlertPreferences();

  /// Por defecto: aviso medio + aviso fuerte (comportamiento anterior).
  static const defaultRadarAnnounceDistances = <double>[350, 90];

  /// Márgenes típicos (km/h por encima del límite) para empezar a avisar.
  static const speedLimitToleranceOptions = <int>[0, 3, 5, 7, 10];

  final bool radarsEnabled;
  final bool radarShowOnMap;

  /// Iconos de radar en la vista previa de ruta (por defecto off: rutas largas).
  final bool radarShowOnPreview;
  final bool radarVoiceEnabled;

  /// Distancias de aviso de radar (varias). Orden interno: mayor → menor.
  final List<double> radarAnnounceDistances;

  final bool fuelEnabled;
  final bool fuelShowOnMap;

  /// Iconos de gasolinera en la vista previa de ruta (por defecto off).
  final bool fuelShowOnPreview;
  final bool fuelShowPrice;

  /// Si está activo, solo se muestran gasolineras cuyo precio de referencia
  /// (combustible del vehículo o el más barato disponible) sea ≤ [fuelMaxPriceEur].
  final bool fuelPriceFilterEnabled;

  /// Precio máximo manual en €/L (introducido por el usuario).
  final double? fuelMaxPriceEur;

  final bool fuelVoiceEnabled;
  final double fuelAnnounceMeters;

  final bool tollsEnabled;
  final bool tollShowOnMap;

  /// Iconos de peaje en la vista previa de ruta (por defecto off).
  final bool tollShowOnPreview;
  final bool tollVoiceEnabled;
  final double tollAnnounceMeters;

  final bool curvesEnabled;
  final bool curvesShowOnMap;

  /// Iconos de curva en la vista previa de ruta (por defecto off).
  final bool curvesShowOnPreview;
  final bool curvesVoiceEnabled;

  /// Tipos de curva visibles / anunciables (por defecto: cerrada + muy cerrada).
  final bool curveOpenEnabled;
  final bool curvePronouncedEnabled;
  final bool curveTightEnabled;
  final bool curveVeryClosedEnabled;

  /// Aviso visual (y opcional sonoro) al superar el límite de la vía.
  final bool speedLimitAlertEnabled;

  /// km/h de margen sobre el límite antes de avisar (0 = al pasarlo).
  final int speedLimitToleranceKmh;

  /// Pitido corto la primera vez que te pasas; se rearma al volver bajo el umbral.
  final bool speedLimitSoundEnabled;

  /// Controles de tráfico en el mapa (semáforo, STOP, ceda). Solo visual.
  final bool trafficSignsEnabled;
  final bool trafficSignalShowOnMap;
  final bool stopShowOnMap;
  final bool giveWayShowOnMap;

  /// Opciones de distancia para la UI.
  static const radarAnnounceOptions = <double>[800, 500, 350, 200, 150, 90, 50];
  static const fuelAnnounceOptions = <double>[500, 800, 1200, 2000];
  static const tollAnnounceOptions = <double>[400, 800, 1200];

  /// Precio máximo aplicado al filtrar gasolineras en ruta.
  double? get activeFuelMaxPriceEur {
    if (!fuelPriceFilterEnabled) {
      return null;
    }
    final price = fuelMaxPriceEur;
    if (price == null || price <= 0) {
      return null;
    }
    return price;
  }

  /// Parsea texto manual (admite coma o punto decimal).
  static double? parseFuelMaxPriceInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0 || value > 9.99) {
      return null;
    }
    return value;
  }

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

  bool isCurveSeverityEnabled(CurveSeverity? severity) {
    if (!curvesEnabled) {
      return false;
    }
    return switch (severity ?? CurveSeverity.pronounced) {
      CurveSeverity.open => curveOpenEnabled,
      CurveSeverity.pronounced => curvePronouncedEnabled,
      CurveSeverity.tight => curveTightEnabled,
      CurveSeverity.hairpin => curveVeryClosedEnabled,
    };
  }

  bool acceptsCurveAlert(RouteAlert alert) {
    if (alert.type != RouteAlertType.sharpCurve) {
      return true;
    }
    return isCurveSeverityEnabled(alert.curveSeverity);
  }

  /// Distancia para mostrar el panel de curva en el HUD.
  double get curveHudMeters => NavigationConstants.curveHudMeters;

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

  bool showAlertOnMap(RouteAlert alert) {
    if (!showTypeOnMap(alert.type)) {
      return false;
    }
    return acceptsCurveAlert(alert);
  }

  bool showTypeOnPreview(RouteAlertType type) {
    if (!isTypeEnabled(type)) {
      return false;
    }
    return switch (type) {
      RouteAlertType.speedCamera => radarShowOnPreview,
      RouteAlertType.fuel => fuelShowOnPreview,
      RouteAlertType.toll => tollShowOnPreview,
      RouteAlertType.sharpCurve => curvesShowOnPreview,
    };
  }

  bool showAlertOnPreview(RouteAlert alert) {
    if (!showTypeOnPreview(alert.type)) {
      return false;
    }
    return acceptsCurveAlert(alert);
  }

  /// Semáforo / STOP / ceda en el mapa (vista previa y navegación).
  bool showMapPoiOnMap(RouteMapPoiKind kind) {
    if (!trafficSignsEnabled) {
      return false;
    }
    return switch (kind) {
      RouteMapPoiKind.trafficSignal => trafficSignalShowOnMap,
      RouteMapPoiKind.stop => stopShowOnMap,
      RouteMapPoiKind.giveWay => giveWayShowOnMap,
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

  /// true si la velocidad actual debe marcarse como exceso según preferencias.
  bool isOverspeed({
    required double speedKmh,
    required int? limitKmh,
  }) {
    if (!speedLimitAlertEnabled) {
      return false;
    }
    if (limitKmh == null || limitKmh <= 0) {
      return false;
    }
    final margin = speedLimitToleranceKmh.clamp(0, 30);
    return speedKmh > limitKmh + margin;
  }

  double announceMetersFor(RouteAlertType type) => switch (type) {
        RouteAlertType.speedCamera => radarHudMeters,
        RouteAlertType.fuel => fuelAnnounceMeters,
        RouteAlertType.toll => tollAnnounceMeters,
        RouteAlertType.sharpCurve => NavigationConstants.curveAnnounceMeters,
      };

  String get enrichCacheSuffix => [
        radarsEnabled ? '1' : '0',
        fuelEnabled ? '1' : '0',
        tollsEnabled ? '1' : '0',
        curvesEnabled ? '1' : '0',
        curveOpenEnabled ? '1' : '0',
        curvePronouncedEnabled ? '1' : '0',
        curveTightEnabled ? '1' : '0',
        curveVeryClosedEnabled ? '1' : '0',
        fuelShowPrice ? '1' : '0',
        fuelPriceFilterEnabled ? '1' : '0',
        fuelMaxPriceEur?.toStringAsFixed(3) ?? 'none',
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
    bool? radarShowOnPreview,
    bool? radarVoiceEnabled,
    List<double>? radarAnnounceDistances,
    bool? fuelEnabled,
    bool? fuelShowOnMap,
    bool? fuelShowOnPreview,
    bool? fuelShowPrice,
    bool? fuelPriceFilterEnabled,
    double? fuelMaxPriceEur,
    bool clearFuelMaxPriceEur = false,
    bool? fuelVoiceEnabled,
    double? fuelAnnounceMeters,
    bool? tollsEnabled,
    bool? tollShowOnMap,
    bool? tollShowOnPreview,
    bool? tollVoiceEnabled,
    double? tollAnnounceMeters,
    bool? curvesEnabled,
    bool? curvesShowOnMap,
    bool? curvesShowOnPreview,
    bool? curvesVoiceEnabled,
    bool? curveOpenEnabled,
    bool? curvePronouncedEnabled,
    bool? curveTightEnabled,
    bool? curveVeryClosedEnabled,
    bool? speedLimitAlertEnabled,
    int? speedLimitToleranceKmh,
    bool? speedLimitSoundEnabled,
    bool? trafficSignsEnabled,
    bool? trafficSignalShowOnMap,
    bool? stopShowOnMap,
    bool? giveWayShowOnMap,
  }) {
    return AlertPreferences(
      radarsEnabled: radarsEnabled ?? this.radarsEnabled,
      radarShowOnMap: radarShowOnMap ?? this.radarShowOnMap,
      radarShowOnPreview: radarShowOnPreview ?? this.radarShowOnPreview,
      radarVoiceEnabled: radarVoiceEnabled ?? this.radarVoiceEnabled,
      radarAnnounceDistances: radarAnnounceDistances != null
          ? _normalizeDistances(radarAnnounceDistances)
          : this.radarAnnounceDistances,
      fuelEnabled: fuelEnabled ?? this.fuelEnabled,
      fuelShowOnMap: fuelShowOnMap ?? this.fuelShowOnMap,
      fuelShowOnPreview: fuelShowOnPreview ?? this.fuelShowOnPreview,
      fuelShowPrice: fuelShowPrice ?? this.fuelShowPrice,
      fuelPriceFilterEnabled:
          fuelPriceFilterEnabled ?? this.fuelPriceFilterEnabled,
      fuelMaxPriceEur: clearFuelMaxPriceEur
          ? null
          : (fuelMaxPriceEur ?? this.fuelMaxPriceEur),
      fuelVoiceEnabled: fuelVoiceEnabled ?? this.fuelVoiceEnabled,
      fuelAnnounceMeters: fuelAnnounceMeters ?? this.fuelAnnounceMeters,
      tollsEnabled: tollsEnabled ?? this.tollsEnabled,
      tollShowOnMap: tollShowOnMap ?? this.tollShowOnMap,
      tollShowOnPreview: tollShowOnPreview ?? this.tollShowOnPreview,
      tollVoiceEnabled: tollVoiceEnabled ?? this.tollVoiceEnabled,
      tollAnnounceMeters: tollAnnounceMeters ?? this.tollAnnounceMeters,
      curvesEnabled: curvesEnabled ?? this.curvesEnabled,
      curvesShowOnMap: curvesShowOnMap ?? this.curvesShowOnMap,
      curvesShowOnPreview: curvesShowOnPreview ?? this.curvesShowOnPreview,
      curvesVoiceEnabled: curvesVoiceEnabled ?? this.curvesVoiceEnabled,
      curveOpenEnabled: curveOpenEnabled ?? this.curveOpenEnabled,
      curvePronouncedEnabled:
          curvePronouncedEnabled ?? this.curvePronouncedEnabled,
      curveTightEnabled: curveTightEnabled ?? this.curveTightEnabled,
      curveVeryClosedEnabled:
          curveVeryClosedEnabled ?? this.curveVeryClosedEnabled,
      speedLimitAlertEnabled:
          speedLimitAlertEnabled ?? this.speedLimitAlertEnabled,
      speedLimitToleranceKmh:
          speedLimitToleranceKmh ?? this.speedLimitToleranceKmh,
      speedLimitSoundEnabled:
          speedLimitSoundEnabled ?? this.speedLimitSoundEnabled,
      trafficSignsEnabled: trafficSignsEnabled ?? this.trafficSignsEnabled,
      trafficSignalShowOnMap:
          trafficSignalShowOnMap ?? this.trafficSignalShowOnMap,
      stopShowOnMap: stopShowOnMap ?? this.stopShowOnMap,
      giveWayShowOnMap: giveWayShowOnMap ?? this.giveWayShowOnMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'radarsEnabled': radarsEnabled,
        'radarShowOnMap': radarShowOnMap,
        'radarShowOnPreview': radarShowOnPreview,
        'radarVoiceEnabled': radarVoiceEnabled,
        'radarAnnounceDistances': radarAnnounceDistances,
        'fuelEnabled': fuelEnabled,
        'fuelShowOnMap': fuelShowOnMap,
        'fuelShowOnPreview': fuelShowOnPreview,
        'fuelShowPrice': fuelShowPrice,
        'fuelPriceFilterEnabled': fuelPriceFilterEnabled,
        if (fuelMaxPriceEur != null) 'fuelMaxPriceEur': fuelMaxPriceEur,
        'fuelVoiceEnabled': fuelVoiceEnabled,
        'fuelAnnounceMeters': fuelAnnounceMeters,
        'tollsEnabled': tollsEnabled,
        'tollShowOnMap': tollShowOnMap,
        'tollShowOnPreview': tollShowOnPreview,
        'tollVoiceEnabled': tollVoiceEnabled,
        'tollAnnounceMeters': tollAnnounceMeters,
        'curvesEnabled': curvesEnabled,
        'curvesShowOnMap': curvesShowOnMap,
        'curvesShowOnPreview': curvesShowOnPreview,
        'curvesVoiceEnabled': curvesVoiceEnabled,
        'curveOpenEnabled': curveOpenEnabled,
        'curvePronouncedEnabled': curvePronouncedEnabled,
        'curveTightEnabled': curveTightEnabled,
        'curveVeryClosedEnabled': curveVeryClosedEnabled,
        'speedLimitAlertEnabled': speedLimitAlertEnabled,
        'speedLimitToleranceKmh': speedLimitToleranceKmh,
        'speedLimitSoundEnabled': speedLimitSoundEnabled,
        'trafficSignsEnabled': trafficSignsEnabled,
        'trafficSignalShowOnMap': trafficSignalShowOnMap,
        'stopShowOnMap': stopShowOnMap,
        'giveWayShowOnMap': giveWayShowOnMap,
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
      radarShowOnPreview: flag('radarShowOnPreview', false),
      radarVoiceEnabled: flag('radarVoiceEnabled', true),
      radarAnnounceDistances: distances,
      fuelEnabled: flag('fuelEnabled', true),
      fuelShowOnMap: flag('fuelShowOnMap', true),
      fuelShowOnPreview: flag('fuelShowOnPreview', false),
      fuelShowPrice: flag('fuelShowPrice', true),
      fuelPriceFilterEnabled: flag(
        'fuelPriceFilterEnabled',
        json['fuelMaxPriceEur'] is num,
      ),
      fuelMaxPriceEur: () {
        final v = json['fuelMaxPriceEur'];
        if (v is num && v > 0) {
          return v.toDouble();
        }
        return null;
      }(),
      fuelVoiceEnabled: flag('fuelVoiceEnabled', false),
      fuelAnnounceMeters: meters(
        'fuelAnnounceMeters',
        NavigationConstants.fuelAnnounceMeters,
      ),
      tollsEnabled: flag('tollsEnabled', true),
      tollShowOnMap: flag('tollShowOnMap', true),
      tollShowOnPreview: flag('tollShowOnPreview', false),
      tollVoiceEnabled: flag('tollVoiceEnabled', true),
      tollAnnounceMeters: meters(
        'tollAnnounceMeters',
        NavigationConstants.tollAnnounceMeters,
      ),
      curvesEnabled: flag('curvesEnabled', true),
      curvesShowOnMap: flag('curvesShowOnMap', false),
      curvesShowOnPreview: flag('curvesShowOnPreview', false),
      curvesVoiceEnabled: flag('curvesVoiceEnabled', false),
      curveOpenEnabled: flag('curveOpenEnabled', false),
      curvePronouncedEnabled: flag('curvePronouncedEnabled', false),
      curveTightEnabled: flag('curveTightEnabled', true),
      curveVeryClosedEnabled: flag('curveVeryClosedEnabled', true),
      speedLimitAlertEnabled: flag('speedLimitAlertEnabled', true),
      speedLimitToleranceKmh: () {
        final v = json['speedLimitToleranceKmh'];
        if (v is num) {
          return v.toInt().clamp(0, 30);
        }
        return 5;
      }(),
      speedLimitSoundEnabled: flag('speedLimitSoundEnabled', true),
      trafficSignsEnabled: flag('trafficSignsEnabled', true),
      trafficSignalShowOnMap: flag('trafficSignalShowOnMap', true),
      stopShowOnMap: flag('stopShowOnMap', true),
      giveWayShowOnMap: flag('giveWayShowOnMap', true),
    );
  }

  @override
  List<Object?> get props => [
        radarsEnabled,
        radarShowOnMap,
        radarShowOnPreview,
        radarVoiceEnabled,
        radarAnnounceDistances,
        fuelEnabled,
        fuelShowOnMap,
        fuelShowOnPreview,
        fuelShowPrice,
        fuelPriceFilterEnabled,
        fuelMaxPriceEur,
        fuelVoiceEnabled,
        fuelAnnounceMeters,
        tollsEnabled,
        tollShowOnMap,
        tollShowOnPreview,
        tollVoiceEnabled,
        tollAnnounceMeters,
        curvesEnabled,
        curvesShowOnMap,
        curvesShowOnPreview,
        curvesVoiceEnabled,
        curveOpenEnabled,
        curvePronouncedEnabled,
        curveTightEnabled,
        curveVeryClosedEnabled,
        speedLimitAlertEnabled,
        speedLimitToleranceKmh,
        speedLimitSoundEnabled,
        trafficSignsEnabled,
        trafficSignalShowOnMap,
        stopShowOnMap,
        giveWayShowOnMap,
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
