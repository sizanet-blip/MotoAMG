import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loc_motos/features/navigation/domain/entities/lane_guidance.dart';
import 'package:loc_motos/features/navigation/presentation/theme/navigation_hud_theme.dart';

/// Panel 2D de control de carriles (activos rellenos, resto contorno).
class NavigationLaneGuidancePanel extends StatelessWidget {
  const NavigationLaneGuidancePanel({
    super.key,
    required this.lanes,
  });

  final List<LaneInfo> lanes;

  @override
  Widget build(BuildContext context) {
    if (lanes.length < 2) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavigationHudTheme.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lanes.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _LaneCell(lane: lanes[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _LaneCell extends StatelessWidget {
  const _LaneCell({required this.lane});

  final LaneInfo lane;

  @override
  Widget build(BuildContext context) {
    final recommended = lane.isRecommended;
    final active = lane.isActive;
    final fill = active
        ? NavigationHudTheme.accentStrong
        : recommended
            ? NavigationHudTheme.accentStrong.withValues(alpha: 0.72)
            : Colors.transparent;
    final border = active || recommended
        ? NavigationHudTheme.accent
        : NavigationHudTheme.textSecondary.withValues(alpha: 0.45);
    final arrowColor = active || recommended
        ? Colors.white
        : NavigationHudTheme.textSecondary.withValues(alpha: 0.75);

    return Container(
      width: 36,
      height: 56,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.4),
      ),
      child: CustomPaint(
        painter: _LaneArrowsPainter(
          mask: lane.displayMask,
          color: arrowColor,
          emphasize: active || recommended,
        ),
      ),
    );
  }
}

class _LaneArrowsPainter extends CustomPainter {
  _LaneArrowsPainter({
    required this.mask,
    required this.color,
    required this.emphasize,
  });

  final int mask;
  final Color color;
  final bool emphasize;

  @override
  void paint(Canvas canvas, Size size) {
    final bits = laneArrowBits(mask);
    final drawBits =
        bits.isEmpty ? const [LaneDirectionBits.through] : bits;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasize ? 2.4 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final n = drawBits.length;
    for (var i = 0; i < n; i++) {
      final cx = size.width * ((i + 1) / (n + 1));
      _drawArrow(canvas, size, cx, drawBits[i], paint);
    }
  }

  void _drawArrow(
    Canvas canvas,
    Size size,
    double cx,
    int bit,
    Paint paint,
  ) {
    final start = Offset(cx, size.height * 0.82);
    final len = size.height * 0.36;

    if (bit == LaneDirectionBits.reverse) {
      final path = Path()
        ..moveTo(start.dx + 4, start.dy)
        ..lineTo(start.dx + 4, start.dy - len * 0.55)
        ..arcToPoint(
          Offset(start.dx - 4, start.dy - len * 0.55),
          radius: const Radius.circular(4),
          clockwise: false,
        )
        ..lineTo(start.dx - 4, start.dy - len * 0.12);
      canvas.drawPath(path, paint);
      _arrowHead(
        canvas,
        Offset(start.dx - 4, start.dy - len * 0.12),
        math.pi / 2,
        paint,
      );
      return;
    }

    final tip = switch (bit) {
      LaneDirectionBits.sharpLeft =>
        Offset(start.dx - len * 0.7, start.dy - len * 0.55),
      LaneDirectionBits.left =>
        Offset(start.dx - len * 0.55, start.dy - len * 0.75),
      LaneDirectionBits.slightLeft || LaneDirectionBits.mergeToLeft =>
        Offset(start.dx - len * 0.28, start.dy - len * 0.9),
      LaneDirectionBits.slightRight || LaneDirectionBits.mergeToRight =>
        Offset(start.dx + len * 0.28, start.dy - len * 0.9),
      LaneDirectionBits.right =>
        Offset(start.dx + len * 0.55, start.dy - len * 0.75),
      LaneDirectionBits.sharpRight =>
        Offset(start.dx + len * 0.7, start.dy - len * 0.55),
      _ => Offset(start.dx, start.dy - len),
    };

    canvas.drawLine(start, tip, paint);
    _arrowHead(canvas, tip, (tip - start).direction, paint);
  }

  void _arrowHead(Canvas canvas, Offset tip, double dir, Paint paint) {
    const head = 5.5;
    final left = Offset(
      tip.dx + math.cos(dir + math.pi * 0.78) * head,
      tip.dy + math.sin(dir + math.pi * 0.78) * head,
    );
    final right = Offset(
      tip.dx + math.cos(dir - math.pi * 0.78) * head,
      tip.dy + math.sin(dir - math.pi * 0.78) * head,
    );
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }

  @override
  bool shouldRepaint(covariant _LaneArrowsPainter oldDelegate) =>
      oldDelegate.mask != mask ||
      oldDelegate.color != color ||
      oldDelegate.emphasize != emphasize;
}
