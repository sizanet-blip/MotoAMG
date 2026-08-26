import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loc_motos/core/utils/distance_format.dart';
import 'package:loc_motos/features/navigation/data/services/route_guidance_service.dart';
import 'package:loc_motos/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';

/// Etiqueta corta para HUD (sin calle; la voz lleva el detalle).
String maneuverHudAction(NavigationManeuver m) {
  return switch (m.type) {
    ManeuverType.depart => 'Salida',
    ManeuverType.arrive => 'Llegada',
    ManeuverType.turnLeft => 'Izquierda',
    ManeuverType.turnRight => 'Derecha',
    ManeuverType.turn => 'Cambio sentido',
    ManeuverType.continueStraight => 'Recto',
    ManeuverType.roundabout => m.roundaboutExit != null && m.roundaboutExit! > 0
        ? 'Salida ${m.roundaboutExit}'
        : 'Rotonda',
    ManeuverType.merge => 'Incorpórese',
    ManeuverType.ramp => 'Salida',
    ManeuverType.unknown => 'Continúe',
  };
}

/// Tarjeta de maniobra compacta (ancho al contenido, no a pantalla completa).
class NavigationManeuverCard extends StatelessWidget {
  const NavigationManeuverCard({
    super.key,
    required this.maneuver,
    this.nextManeuver,
    this.remainingMeters,
  });

  final NavigationManeuver maneuver;
  final NavigationManeuver? nextManeuver;
  final double? remainingMeters;

  @override
  Widget build(BuildContext context) {
    final distance = remainingMeters ?? maneuver.distanceMeters;
    final showNext = shouldShowNextManeuverHint(maneuver, nextManeuver);
    final action = maneuverHudAction(maneuver);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavigationHudTheme.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ManeuverIcon(
              type: maneuver.type,
              roundaboutExit: maneuver.roundaboutExit,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatRideDistance(distance),
                    style: const TextStyle(
                      color: NavigationHudTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    action,
                    style: const TextStyle(
                      color: NavigationHudTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showNext && nextManeuver != null)
                    Text(
                      '→ ${maneuverHudAction(nextManeuver!)}',
                      style: const TextStyle(
                        color: NavigationHudTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: NavigationHudTheme.accentStrong,
        borderRadius: BorderRadius.circular(11),
      ),
      child: type == ManeuverType.roundabout
          ? _RoundaboutIcon(exitNumber: roundaboutExit)
          : Icon(
              _iconFor(type),
              size: 24,
              color: Colors.white,
            ),
    );
  }
}

class _RoundaboutIcon extends StatelessWidget {
  const _RoundaboutIcon({this.exitNumber});

  final int? exitNumber;

  @override
  Widget build(BuildContext context) {
    final exit = exitNumber;
    if (exit == null || exit <= 0) {
      return const Icon(
        Icons.roundabout_right_rounded,
        size: 24,
        color: Colors.white,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: CustomPaint(
        painter: const _RoundaboutRingPainter(),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$exit',
              style: const TextStyle(
                color: NavigationHudTheme.accentStrong,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundaboutRingPainter extends CustomPainter {
  const _RoundaboutRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    const gapStart = -math.pi * 0.28;
    const sweep = math.pi * 1.78;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      gapStart,
      sweep,
      false,
      ring,
    );

    const exitAngle = -math.pi * 0.22;
    final tick = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final inner = Offset(
      center.dx + (radius - 0.5) * math.cos(exitAngle),
      center.dy + (radius - 0.5) * math.sin(exitAngle),
    );
    final outer = Offset(
      center.dx + (radius + 3.5) * math.cos(exitAngle),
      center.dy + (radius + 3.5) * math.sin(exitAngle),
    );
    canvas.drawLine(inner, outer, tick);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
