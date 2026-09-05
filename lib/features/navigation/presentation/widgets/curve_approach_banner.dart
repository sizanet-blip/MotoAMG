import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moto_amg/core/utils/distance_format.dart';
import 'package:moto_amg/features/navigation/domain/entities/route_alert.dart';
import 'package:moto_amg/features/navigation/presentation/theme/navigation_hud_theme.dart';

/// Panel de curva separado del cartel de indicaciones (HUD).
class CurveApproachBanner extends StatelessWidget {
  const CurveApproachBanner({
    super.key,
    required this.alert,
    required this.remainingMeters,
    this.compact = false,
  });

  final RouteAlert alert;
  final double remainingMeters;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final severity = alert.effectiveCurveSeverity;
    final turn = alert.curveTurn ?? CurveTurn.right;
    final accent = Color(severity.mapColorArgb);
    final imminent = remainingMeters <= 55;
    final title = severity.shortLabel;
    final side = turn.shortLabel.toLowerCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        color: Color.lerp(
          NavigationHudTheme.panel,
          accent,
          imminent ? 0.35 : 0.22,
        )!.withValues(alpha: 0.96),
        border: Border.all(
          color: accent.withValues(alpha: imminent ? 0.85 : 0.55),
          width: imminent ? 2 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 10,
          compact ? 6 : 8,
          compact ? 10 : 14,
          compact ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 52 : 64,
              height: compact ? 52 : 64,
              child: CustomPaint(
                painter: _CurveRoadPainter(
                  severity: severity,
                  turn: turn,
                  accent: accent,
                ),
              ),
            ),
            SizedBox(width: compact ? 6 : 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 132 : 168),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    imminent ? 'Curva $side' : 'Próxima curva',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 11 : 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.98),
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 15 : 17,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    formatRideDistance(remainingMeters),
                    style: TextStyle(
                      color: NavigationHudTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 12 : 13,
                    ),
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

class _CurveRoadPainter extends CustomPainter {
  const _CurveRoadPainter({
    required this.severity,
    required this.turn,
    required this.accent,
  });

  final CurveSeverity severity;
  final CurveTurn turn;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.58);
    final radius = size.shortestSide * 0.34;
    final sweep = switch (severity) {
      CurveSeverity.open => math.pi * 0.45,
      CurveSeverity.pronounced => math.pi * 0.62,
      CurveSeverity.tight => math.pi * 0.82,
      CurveSeverity.hairpin => math.pi * 1.05,
    };
    final start = turn == CurveTurn.right
        ? math.pi * 0.95
        : math.pi * 0.05;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final roadPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final edgePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep * (turn == CurveTurn.right ? -1 : 1),
        false, roadPaint);
    canvas.drawArc(rect, start, sweep * (turn == CurveTurn.right ? -1 : 1),
        false, edgePaint);
    canvas.drawArc(
      rect,
      start + sweep * 0.18 * (turn == CurveTurn.right ? -1 : 1),
      sweep * 0.55 * (turn == CurveTurn.right ? -1 : 1),
      false,
      lanePaint,
    );

    final arrowT = turn == CurveTurn.right ? start - sweep * 0.55 : start + sweep * 0.55;
    final arrow = Offset(
      center.dx + radius * math.cos(arrowT),
      center.dy + radius * math.sin(arrowT),
    );
    final dir = arrowT + (turn == CurveTurn.right ? -math.pi / 2 : math.pi / 2);
    final tip = Offset(
      arrow.dx + 10 * math.cos(dir),
      arrow.dy + 10 * math.sin(dir),
    );
    final wingA = Offset(
      arrow.dx + 7 * math.cos(dir + 2.6),
      arrow.dy + 7 * math.sin(dir + 2.6),
    );
    final wingB = Offset(
      arrow.dx + 7 * math.cos(dir - 2.6),
      arrow.dy + 7 * math.sin(dir - 2.6),
    );
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wingA.dx, wingA.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(wingB.dx, wingB.dy);
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CurveRoadPainter oldDelegate) {
    return oldDelegate.severity != severity ||
        oldDelegate.turn != turn ||
        oldDelegate.accent != accent;
  }
}
