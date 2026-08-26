import 'package:equatable/equatable.dart';

/// Estilo de ruta (aproximación Valhalla: `use_highways` + `top_speed`).
///
/// Valhalla `motorcycle` no calcula curvatura real del trazado. Estos mandos
/// sí cambian la ruta de forma notable en pruebas contra el servidor.
enum RouteCurvatureLevel {
  fast,
  balanced,
  moreCurves,
  maxCurves,
}

extension RouteCurvatureLevelX on RouteCurvatureLevel {
  String get label => switch (this) {
        RouteCurvatureLevel.fast => 'Rápida',
        RouteCurvatureLevel.balanced => 'Equilibrada',
        RouteCurvatureLevel.moreCurves => 'Secundarias',
        RouteCurvatureLevel.maxCurves => 'Solo secundarias',
      };

  String get shortHint => switch (this) {
        RouteCurvatureLevel.fast => 'Máximo tiempo / vías rápidas',
        RouteCurvatureLevel.balanced => 'Compromiso tiempo y secundarias',
        RouteCurvatureLevel.moreCurves => 'Más secundaria, más lenta',
        RouteCurvatureLevel.maxCurves =>
          'Máximo sesgo + alternativa con más giros',
      };

  double get useHighways => switch (this) {
        RouteCurvatureLevel.fast => 0.9,
        RouteCurvatureLevel.balanced => 0.5,
        RouteCurvatureLevel.moreCurves => 0.2,
        RouteCurvatureLevel.maxCurves => 0.0,
      };

  double get useHighwaysWhenAvoiding => switch (this) {
        RouteCurvatureLevel.fast => 0.35,
        RouteCurvatureLevel.balanced => 0.2,
        RouteCurvatureLevel.moreCurves => 0.08,
        RouteCurvatureLevel.maxCurves => 0.0,
      };

  /// Velocidad tope del costing: más baja → Valhalla evita corredores rápidos
  /// y alarga por secundarias (efecto fuerte en pruebas reales).
  int get topSpeedKmh => switch (this) {
        RouteCurvatureLevel.fast => 120,
        RouteCurvatureLevel.balanced => 85,
        RouteCurvatureLevel.moreCurves => 50,
        RouteCurvatureLevel.maxCurves => 38,
      };

  /// Alternativas Valhalla a pedir (0 = solo la principal).
  int get alternateCount => switch (this) {
        RouteCurvatureLevel.fast => 0,
        RouteCurvatureLevel.balanced => 1,
        RouteCurvatureLevel.moreCurves => 2,
        RouteCurvatureLevel.maxCurves => 3,
      };

  /// Si true, entre alternativas se elige la de más giros / más “revirada”.
  bool get preferTwistierAlternate => switch (this) {
        RouteCurvatureLevel.fast => false,
        RouteCurvatureLevel.balanced => false,
        RouteCurvatureLevel.moreCurves => true,
        RouteCurvatureLevel.maxCurves => true,
      };
}

/// Preferencias de routing moto para Valhalla.
class RoutePreferences extends Equatable {
  const RoutePreferences({
    this.curvature = RouteCurvatureLevel.moreCurves,
    this.avoidHighways = false,
    this.avoidTolls = false,
    this.avoidUnpaved = true,
    this.avoidFerries = false,
  });

  final RouteCurvatureLevel curvature;
  final bool avoidHighways;
  final bool avoidTolls;
  final bool avoidUnpaved;
  final bool avoidFerries;

  static const defaults = RoutePreferences();

  int get activeAvoidanceCount {
    var n = 0;
    if (avoidHighways) n++;
    if (avoidTolls) n++;
    if (avoidUnpaved) n++;
    if (avoidFerries) n++;
    return n;
  }

  String get summaryLabel {
    final avoid = activeAvoidanceCount;
    if (avoid == 0) {
      return curvature.label;
    }
    return '${curvature.label} · $avoid evitaci'
        '${avoid == 1 ? 'ón' : 'ones'}';
  }

  /// Opciones Valhalla según costing (`motorcycle` / `auto` / `truck`).
  Map<String, dynamic> toValhallaCostingOptions(String costing) {
    if (costing == 'motorcycle') {
      final useHighways = avoidHighways
          ? curvature.useHighwaysWhenAvoiding
          : curvature.useHighways;
      return {
        'use_highways': useHighways,
        'top_speed': curvature.topSpeedKmh,
        'use_tolls': avoidTolls ? 0.0 : 0.5,
        'use_ferry': avoidFerries ? 0.0 : 0.5,
        'use_trails': avoidUnpaved ? 0.0 : 0.0,
        'use_tracks': avoidUnpaved ? 0.0 : 0.0,
      };
    }

    // auto / truck: evitaciones sin perfil de curvas.
    return {
      'use_highways': avoidHighways ? 0.0 : 1.0,
      'use_tolls': avoidTolls ? 0.0 : 1.0,
      'use_ferry': avoidFerries ? 0.0 : 1.0,
      if (costing == 'auto') 'use_tracks': avoidUnpaved ? 0.0 : 0.5,
    };
  }

  RoutePreferences copyWith({
    RouteCurvatureLevel? curvature,
    bool? avoidHighways,
    bool? avoidTolls,
    bool? avoidUnpaved,
    bool? avoidFerries,
  }) {
    return RoutePreferences(
      curvature: curvature ?? this.curvature,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidUnpaved: avoidUnpaved ?? this.avoidUnpaved,
      avoidFerries: avoidFerries ?? this.avoidFerries,
    );
  }

  Map<String, dynamic> toJson() => {
        'curvature': curvature.name,
        'avoidHighways': avoidHighways,
        'avoidTolls': avoidTolls,
        'avoidUnpaved': avoidUnpaved,
        'avoidFerries': avoidFerries,
      };

  factory RoutePreferences.fromJson(Map<String, dynamic> json) {
    final name = json['curvature'] as String?;
    final curvature = RouteCurvatureLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => RouteCurvatureLevel.moreCurves,
    );
    return RoutePreferences(
      curvature: curvature,
      avoidHighways: json['avoidHighways'] as bool? ?? false,
      avoidTolls: json['avoidTolls'] as bool? ?? false,
      avoidUnpaved: json['avoidUnpaved'] as bool? ?? true,
      avoidFerries: json['avoidFerries'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        curvature,
        avoidHighways,
        avoidTolls,
        avoidUnpaved,
        avoidFerries,
      ];
}
