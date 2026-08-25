import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';

class NavigationManeuverCard extends StatelessWidget {
  const NavigationManeuverCard({
    super.key,
    required this.maneuver,
    this.nextManeuver,
    this.remainingMeters,
    this.onClose,
  });

  final NavigationManeuver maneuver;
  final NavigationManeuver? nextManeuver;

  /// Distancia restante real hasta el final del tramo; si null usa length Valhalla.
  final double? remainingMeters;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final distance = remainingMeters ?? maneuver.distanceMeters;
    final showNext = shouldShowNextManeuverHint(maneuver, nextManeuver);

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
                  _ManeuverIcon(
                    type: maneuver.type,
                    roundaboutExit: maneuver.roundaboutExit,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatRideDistance(distance),
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
                        if (maneuver.streetName != null &&
                            !_instructionMentionsStreet(
                              maneuver.instruction,
                              maneuver.streetName!,
                            )) ...[
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
            if (showNext && nextManeuver != null)
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

  bool _instructionMentionsStreet(String instruction, String street) {
    return instruction.toLowerCase().contains(street.toLowerCase());
  }
}

class _ManeuverIcon extends StatelessWidget {
  const _ManeuverIcon({
    required this.type,
    this.roundaboutExit,
  });

  final ManeuverType type;
  final int? roundaboutExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: NavigationHudTheme.accentStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: type == ManeuverType.roundabout
          ? _RoundaboutIcon(exitNumber: roundaboutExit)
          : Icon(
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
      ManeuverType.turn => Icons.u_turn_right_rounded,
      ManeuverType.turnLeft => Icons.turn_left_rounded,
      ManeuverType.turnRight => Icons.turn_right_rounded,
      ManeuverType.continueStraight => Icons.straight_rounded,
      ManeuverType.roundabout => Icons.roundabout_right_rounded,
      ManeuverType.merge => Icons.merge_rounded,
      ManeuverType.ramp => Icons.ramp_right_rounded,
      ManeuverType.unknown => Icons.navigation_rounded,
    };
  }
}

/// Rotonda: anillo + salida, con el nº en pastilla blanca (lectura rápida).
class _RoundaboutIcon extends StatelessWidget {
  const _RoundaboutIcon({this.exitNumber});

  final int? exitNumber;

  @override
  Widget build(BuildContext context) {
    final exit = exitNumber;
    if (exit == null || exit <= 0) {
      return const Icon(
        Icons.roundabout_right_rounded,
        size: 32,
        color: Colors.white,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(5),
      child: CustomPaint(
        painter: const _RoundaboutRingPainter(),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '$exit',
              style: const TextStyle(
                color: NavigationHudTheme.accentStrong,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo casi cerrado con marquesina de salida (circulación a la derecha).
class _RoundaboutRingPainter extends CustomPainter {
  const _RoundaboutRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2.5;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Hueco arriba-derecha para la salida.
    const gapStart = -math.pi * 0.28;
    const sweep = math.pi * 1.78;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      gapStart,
      sweep,
      false,
      ring,
    );

    // Marquesina / flecha de salida.
    const exitAngle = -math.pi * 0.22;
    final tick = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final inner = Offset(
      center.dx + (radius - 0.5) * math.cos(exitAngle),
      center.dy + (radius - 0.5) * math.sin(exitAngle),
    );
    final outer = Offset(
      center.dx + (radius + 5.5) * math.cos(exitAngle),
      center.dy + (radius + 5.5) * math.sin(exitAngle),
    );
    canvas.drawLine(inner, outer, tick);

    // Pequeña punta en la marquesina.
    final tipAngle = exitAngle - 0.55;
    final tip = Offset(
      outer.dx + 4.5 * math.cos(tipAngle),
      outer.dy + 4.5 * math.sin(tipAngle),
    );
    canvas.drawLine(outer, tip, tick);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
