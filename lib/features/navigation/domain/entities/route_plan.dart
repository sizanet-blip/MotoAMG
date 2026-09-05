import 'package:equatable/equatable.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_route.dart';

/// Resultado de planificar: una o varias rutas para que el usuario elija.
class RoutePlan extends Equatable {
  const RoutePlan({
    required this.alternatives,
    this.selectedIndex = 0,
  }) : assert(alternatives.length > 0, 'Hace falta al menos una ruta');

  final List<NavigationRoute> alternatives;
  final int selectedIndex;

  NavigationRoute get selected =>
      alternatives[selectedIndex.clamp(0, alternatives.length - 1)];

  bool get hasAlternatives => alternatives.length > 1;

  /// Rutas no seleccionadas (para pintarlas más claras en el mapa).
  List<NavigationRoute> get otherAlternatives => [
        for (var i = 0; i < alternatives.length; i++)
          if (i != selectedIndex) alternatives[i],
      ];

  RoutePlan select(int index) {
    final clamped = index.clamp(0, alternatives.length - 1);
    if (clamped == selectedIndex) {
      return this;
    }
    return RoutePlan(alternatives: alternatives, selectedIndex: clamped);
  }

  @override
  List<Object?> get props => [alternatives, selectedIndex];
}
