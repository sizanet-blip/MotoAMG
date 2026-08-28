import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loc_motos/features/groups/domain/entities/group_stop.dart';

/// Pin de mapa para paradas de grupo (no moto): visible y anclado por la punta.
abstract final class GroupStopMapMarker {
  static Future<Uint8List> toPng({
    required GroupStopType type,
    required Color color,
    double logicalWidth = 88,
  }) async {
    final width = logicalWidth;
    final height = logicalWidth * 1.28;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paint(
      canvas,
      Size(width, height),
      color: color,
      letter: _letter(type),
    );
    final image = await recorder.endRecording().toImage(
      width.ceil(),
      height.ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static String _letter(GroupStopType type) => switch (type) {
        GroupStopType.cafe => 'C',
        GroupStopType.gasolinera => 'G',
        GroupStopType.esperarAqui => 'E',
        GroupStopType.reunion => 'R',
      };

  static void _paint(
    Canvas canvas,
    Size size, {
    required Color color,
    required String letter,
  }) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );

    final cx = size.width / 2;
    final headRadius = size.width * 0.34;
    final headCenter = Offset(cx, headRadius + 6);

    final pin = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
      ..moveTo(cx - headRadius * 0.52, headCenter.dy + headRadius * 0.62)
      ..lineTo(cx, size.height - 4)
      ..lineTo(cx + headRadius * 0.52, headCenter.dy + headRadius * 0.62)
      ..close();

    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(pin, Paint()..color = color);

    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: headRadius * 1.05,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        cx - textPainter.width / 2,
        headCenter.dy - textPainter.height / 2,
      ),
    );
  }
}
