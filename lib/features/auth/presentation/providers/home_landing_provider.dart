import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sección visible en el aterrizaje (fuera de un grupo abierto).
enum HomeLandingSection {
  hub,
  groups,
}

final homeLandingSectionProvider =
    StateProvider<HomeLandingSection>((ref) => HomeLandingSection.hub);
