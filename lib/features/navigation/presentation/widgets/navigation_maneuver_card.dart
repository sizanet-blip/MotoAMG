import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moto_amg/core/constants/navigation_constants.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/features/navigation/data/services/route_guidance_service.dart';
import 'package:moto_amg/features/navigation/domain/entities/navigation_maneuver.dart';
import 'package:moto_amg/features/navigation/domain/services/maneuver_significance.dart';
import 'package:moto_amg/features/navigation/presentation/theme/navigation_hud_theme.dart';

/// Etiqueta corta de acción (la calle va aparte).
String maneuverHudAction(NavigationManeuver m) {
  if (ManeuverSignificance.isForkBearManeuver(m)) {
    final t = m.instruction.toLowerCase();
    if (t.contains('izquierda')) {
      return 'Mantén la izquierda';
    }
    return 'Mantén la derecha';
  }
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

enum ManeuverBannerUrgency { normal, approaching, imminent }

ManeuverBannerUrgency maneuverBannerUrgency(double? remainingMeters) {
  final m = remainingMeters;
  if (m == null) {
    return ManeuverBannerUrgency.normal;
  }
  if (m <= NavigationConstants.maneuverImminentMeters) {
    return ManeuverBannerUrgency.imminent;
  }
  if (m <= NavigationConstants.maneuverApproachingMeters) {
    return ManeuverBannerUrgency.approaching;
  }
  return ManeuverBannerUrgency.normal;
}

/// Banner de maniobra dominante (calle + urgencia visual).
class NavigationManeuverCard extends StatelessWidget {
  const NavigationManeuverCard({
    super.key,
    required this.maneuver,
    this.nextManeuver,
    this.remainingMeters,
    this.compact = false,
  });

  final NavigationManeuver maneuver;
  final NavigationManeuver? nextManeuver;
  final double? remainingMeters;

  /// Landscape: icono y tipografía más pequeños.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final distance = remainingMeters ?? maneuver.distanceMeters;
    final showNext = shouldShowNextManeuverHint(maneuver, nextManeuver);
    final action = maneuverHudAction(maneuver);
    final street = maneuver.streetName?.trim();
    final hasStreet = street != null && street.isNotEmpty;
    final urgency = maneuverBannerUrgency(remainingMeters);

    final panelColor = switch (urgency) {
      ManeuverBannerUrgency.imminent => const Color(0xFF1B3A5C),
      ManeuverBannerUrgency.approaching =>
        NavigationHudTheme.panel.withValues(alpha: 0.96),
      ManeuverBannerUrgency.normal =>
        NavigationHudTheme.panel.withValues(alpha: 0.94),
    };
    final accent = switch (urgency) {
      ManeuverBannerUrgency.imminent => NavigationHudTheme.warning,
      ManeuverBannerUrgency.approaching => NavigationHudTheme.accentStrong,
      ManeuverBannerUrgency.normal => NavigationHudTheme.accentStrong,
    };
    final iconSize = switch (urgency) {
      ManeuverBannerUrgency.imminent => compact ? 40.0 : 56.0,
      ManeuverBannerUrgency.approaching => compact ? 36.0 : 50.0,
      ManeuverBannerUrgency.normal => compact ? 34.0 : 48.0,
    };
    final distanceSize = switch (urgency) {
      ManeuverBannerUrgency.imminent => compact ? 20.0 : 28.0,
      ManeuverBannerUrgency.approaching => compact ? 18.0 : 26.0,
      ManeuverBannerUrgency.normal => compact ? 18.0 : 24.0,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: urgency == ManeuverBannerUrgency.imminent
            ? Border.all(
                color: NavigationHudTheme.warning,
                width: compact ? 1 : 1.6,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: urgency == ManeuverBannerUrgency.imminent
                ? (compact
                    ? const Color(0x33F9A825)
                    : const Color(0x66F9A825))
                : const Color(0x55000000),
            blurRadius: urgency == ManeuverBannerUrgency.imminent
                ? (compact ? 6 : 16)
                : (compact ? 8 : 12),
            offset: Offset(0, compact ? 2 : 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 6 : (urgency == ManeuverBannerUrgency.normal ? 10 : 12),
          compact ? 10 : 14,
          compact ? 6 : (urgency == ManeuverBannerUrgency.normal ? 10 : 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ManeuverIcon(
              type: maneuver.type,
              roundaboutExit: maneuver.roundaboutExit,
              size: iconSize,
              accent: accent,
            ),
            SizedBox(width: compact ? 8 : 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 160 : 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatRideDistance(distance),
                    style: TextStyle(
                      color: NavigationHudTheme.textPrimary,
                      fontSize: distanceSize,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    action,
                    style: TextStyle(
                      color: NavigationHudTheme.textPrimary,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasStreet)
                    Text(
                      street,
                      style: TextStyle(
                        color: NavigationHudTheme.textSecondary,
                        fontSize: compact ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!compact && showNext && nextManeuver != null)
                    Text(
                      '→ ${maneuverHudAction(nextManeuver!)}',
                      style: const TextStyle(
                        color: NavigationHudTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
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
    required this.size,
    required this.accent,
    this.roundaboutExit,
  });

  final ManeuverType type;
  final double size;
  final Color accent;
  final int? roundaboutExit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: type == ManeuverType.roundabout
          ? _RoundaboutIcon(exitNumber: roundaboutExit, size: size)
          : Icon(
              _iconFor(type),
              size: size * 0.52,
              color: Colors.white,
            ),
    );
  }
}

class _RoundaboutIcon extends StatelessWidget {
  const _RoundaboutIcon({this.exitNumber, required this.size});

  final int? exitNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final exit = exitNumber;
    if (exit == null || exit <= 0) {
      return Icon(
        Icons.roundabout_right_rounded,
        size: size * 0.52,
        color: Colors.white,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: const _RoundaboutRingPainter(),
        child: Center(
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$exit',
              style: TextStyle(
                color: NavigationHudTheme.accentStrong,
                fontSize: size * 0.24,
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
