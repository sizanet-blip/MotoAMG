import 'package:flutter/material.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';

class NavigationManeuverCard extends StatelessWidget {
  const NavigationManeuverCard({
    super.key,
    required this.maneuver,
    this.nextManeuver,
    this.onClose,
  });

  final NavigationManeuver maneuver;
  final NavigationManeuver? nextManeuver;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavigationHudTheme.panel,
        borderRadius: BorderRadius.circular(NavigationHudTheme.panelRadius),
        boxShadow: const [NavigationHudTheme.panelShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NavigationHudTheme.panelRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ManeuverIcon(type: maneuver.type),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatRideDistance(maneuver.distanceMeters),
                          style: const TextStyle(
                            color: NavigationHudTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          maneuver.instruction,
                          style: const TextStyle(
                            color: NavigationHudTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        if (maneuver.streetName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            maneuver.streetName!,
                            style: const TextStyle(
                              color: NavigationHudTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (maneuver.laneHint != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Carril: ${maneuver.laneHint}',
                            style: const TextStyle(
                              color: NavigationHudTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (maneuver.roundaboutExit != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Salida ${maneuver.roundaboutExit}',
                            style: const TextStyle(
                              color: NavigationHudTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: 'Salir de navegación',
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: NavigationHudTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (nextManeuver != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: NavigationHudTheme.panelElevated,
                child: Text(
                  'Después · ${nextManeuver!.instruction}',
                  style: const TextStyle(
                    color: NavigationHudTheme.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManeuverIcon extends StatelessWidget {
  const _ManeuverIcon({required this.type});

  final ManeuverType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: NavigationHudTheme.accentStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        _iconFor(type),
        size: 32,
        color: Colors.white,
      ),
    );
  }

  IconData _iconFor(ManeuverType type) {
    return switch (type) {
      ManeuverType.depart => Icons.play_arrow_rounded,
      ManeuverType.arrive => Icons.flag_rounded,
      ManeuverType.turn => Icons.turn_right_rounded,
      ManeuverType.continueStraight => Icons.straight_rounded,
      ManeuverType.roundabout => Icons.roundabout_right_rounded,
      ManeuverType.merge => Icons.merge_rounded,
      ManeuverType.ramp => Icons.ramp_right_rounded,
      ManeuverType.unknown => Icons.navigation_rounded,
    };
  }
}
