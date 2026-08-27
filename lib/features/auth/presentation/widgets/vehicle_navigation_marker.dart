import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loc_motos/features/auth/domain/entities/vehicle_map_marker.dart';

/// Silueta vista cenital del vehículo (estilo apps de navegación).
///
/// El morro apunta hacia arriba (−Y) para que `iconRotate` = rumbo GPS funcione.
abstract final class VehicleNavigationMarker {
  static Future<Uint8List> toPng({
    required VehicleMapIcon icon,
    required Color color,
    double logicalSize = 128,
    bool nightMode = false,
  }) async {
    final size = logicalSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(
      canvas,
      Size(size, size),
      icon: icon,
      color: color,
      nightMode: nightMode,
    );
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static void paint(
    Canvas canvas,
    Size size, {
    required VehicleMapIcon icon,
    required Color color,
    bool nightMode = false,
  }) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    // Escala relativa a un lienzo de 128.
    final s = size.shortestSide / 128;
    canvas.scale(s);

    _paintWazeHalo(canvas, nightMode: nightMode);
    switch (icon) {
      case VehicleMapIcon.motorcycle:
        _paintMotorcycle(canvas, color, sport: false);
      case VehicleMapIcon.sportBike:
        _paintMotorcycle(canvas, color, sport: true);
      case VehicleMapIcon.scooter:
        _paintScooter(canvas, color);
      case VehicleMapIcon.car:
        _paintCar(canvas, color, suv: false);
      case VehicleMapIcon.carFilled:
        _paintCar(canvas, color, suv: true);
      case VehicleMapIcon.van:
        _paintVan(canvas, color);
      case VehicleMapIcon.truck:
        _paintTruck(canvas, color);
    }
    canvas.restore();
  }
}

/// Vista previa compacta (perfil / selector).
class VehicleNavigationMarkerPreview extends StatelessWidget {
  const VehicleNavigationMarkerPreview({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final VehicleMapIcon icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VehicleMarkerPainter(icon: icon, color: color),
      ),
    );
  }
}

class _VehicleMarkerPainter extends CustomPainter {
  _VehicleMarkerPainter({required this.icon, required this.color});

  final VehicleMapIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    VehicleNavigationMarker.paint(
      canvas,
      size,
      icon: icon,
      color: color,
    );
  }

  @override
  bool shouldRepaint(covariant _VehicleMarkerPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color.toARGB32() != color.toARGB32();
}

void _paintWazeHalo(Canvas canvas, {bool nightMode = false}) {
  // Halo suave: de día legible; de noche sin “foco” blanco que deslumbre.
  if (nightMode) {
    canvas.drawCircle(
      const Offset(1, 2),
      38,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset.zero,
      34,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          34,
          [
            const Color(0xFF3A4A58).withValues(alpha: 0.42),
            const Color(0xFF1C2530).withValues(alpha: 0.28),
            const Color(0xFF121820).withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    return;
  }

  canvas.drawCircle(
    const Offset(1.5, 2.5),
    42,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawCircle(
    Offset.zero,
    38,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        38,
        [
          const Color(0xFFE8EEF2).withValues(alpha: 0.72),
          const Color(0xFF9AAEB8).withValues(alpha: 0.42),
          const Color(0xFF7A8E98).withValues(alpha: 0.12),
        ],
        const [0.0, 0.7, 1.0],
      ),
  );
}

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

Paint _bodyPaint(Color color, {double halfWidth = 18}) {
  return Paint()
    ..shader = ui.Gradient.linear(
      Offset(-halfWidth, 0),
      Offset(halfWidth, 0),
      [
        _shade(color, -0.16),
        color,
        _shade(color, 0.18),
      ],
      const [0.0, 0.48, 1.0],
    );
}

Paint _strokePaint({double width = 1.1}) => Paint()
  ..color = Colors.black.withValues(alpha: 0.35)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round;

void _paintCar(Canvas canvas, Color color, {required bool suv}) {
  final bodyW = suv ? 34.0 : 30.0;
  final bodyH = suv ? 56.0 : 52.0;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: bodyW, height: bodyH),
    Radius.circular(suv ? 9 : 8),
  );
  canvas.drawRRect(body, _bodyPaint(color, halfWidth: bodyW / 2));
  canvas.drawRRect(body, _strokePaint());

  // Capó / maletero.
  final hood = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -bodyH * 0.28),
      width: bodyW * 0.72,
      height: bodyH * 0.18,
    ),
    const Radius.circular(4),
  );
  canvas.drawRRect(
    hood,
    Paint()..color = Colors.white.withValues(alpha: 0.14),
  );

  // Parabrisas + luneta.
  final glass = Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.55);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -bodyH * 0.06),
        width: bodyW * 0.62,
        height: bodyH * 0.22,
      ),
      const Radius.circular(3.5),
    ),
    glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, bodyH * 0.18),
        width: bodyW * 0.58,
        height: bodyH * 0.14,
      ),
      const Radius.circular(3),
    ),
    glass,
  );

  // Faros.
  final light = Paint()..color = const Color(0xFFFFF8E1);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-bodyW * 0.38, -bodyH * 0.48, bodyW * 0.16, 5),
      const Radius.circular(2),
    ),
    light,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyW * 0.22, -bodyH * 0.48, bodyW * 0.16, 5),
      const Radius.circular(2),
    ),
    light,
  );

  // Luces traseras.
  final rear = Paint()..color = const Color(0xFFE53935);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-bodyW * 0.34, bodyH * 0.42, bodyW * 0.14, 4),
      const Radius.circular(1.5),
    ),
    rear,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyW * 0.2, bodyH * 0.42, bodyW * 0.14, 4),
      const Radius.circular(1.5),
    ),
    rear,
  );

  _paintWheels(canvas, track: bodyW * 0.52, wheelbase: bodyH * 0.58, width: 7, length: 12);
}

void _paintVan(Canvas canvas, Color color) {
  const bodyW = 36.0;
  const bodyH = 60.0;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: bodyW, height: bodyH),
    const Radius.circular(7),
  );
  canvas.drawRRect(body, _bodyPaint(color, halfWidth: bodyW / 2));
  canvas.drawRRect(body, _strokePaint());

  final glass = Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.55);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -18), width: 24, height: 12),
      const Radius.circular(3),
    ),
    glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 8), width: 26, height: 28),
      const Radius.circular(3),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.1),
  );

  final light = Paint()..color = const Color(0xFFFFF8E1);
  canvas.drawCircle(const Offset(-12, -28), 2.8, light);
  canvas.drawCircle(const Offset(12, -28), 2.8, light);

  _paintWheels(canvas, track: 20, wheelbase: 34, width: 7, length: 12);
}

void _paintTruck(Canvas canvas, Color color) {
  final trailer = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(0, 10), width: 34, height: 44),
    const Radius.circular(4),
  );
  canvas.drawRRect(trailer, _bodyPaint(_shade(color, -0.05), halfWidth: 17));
  canvas.drawRRect(trailer, _strokePaint());

  final cab = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(0, -26), width: 30, height: 22),
    const Radius.circular(6),
  );
  canvas.drawRRect(cab, _bodyPaint(color, halfWidth: 15));
  canvas.drawRRect(cab, _strokePaint());

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -28), width: 20, height: 10),
      const Radius.circular(3),
    ),
    Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.55),
  );

  final light = Paint()..color = const Color(0xFFFFF8E1);
  canvas.drawCircle(const Offset(-10, -35), 2.6, light);
  canvas.drawCircle(const Offset(10, -35), 2.6, light);

  _paintWheels(canvas, track: 18, wheelbase: 22, width: 7, length: 11, yOffset: -26);
  _paintWheels(canvas, track: 18, wheelbase: 18, width: 7, length: 11, yOffset: 18);
}

/// Estilo Waze: moto compacta, asiento negro largo, faro claro, manillar fino.
void _paintMotorcycle(Canvas canvas, Color color, {required bool sport}) {
  final body = _bodyPaint(color, halfWidth: 10);
  final seatPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(-6, 0),
      const Offset(6, 0),
      const [
        Color(0xFF1A1A1A),
        Color(0xFF2C2C2C),
        Color(0xFF151515),
      ],
      const [0.0, 0.5, 1.0],
    );
  final tire = Paint()..color = const Color(0xFF111111);

  // Ruedas apenas visibles (como Waze), no discos grandes.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, sport ? -30 : -28), width: 10, height: 7),
      const Radius.circular(3),
    ),
    tire,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, sport ? 30 : 28), width: 11, height: 7),
      const Radius.circular(3),
    ),
    tire,
  );

  // Guardabarros / cola trasera.
  final rearFender = Path()
    ..moveTo(-7.5, sport ? 10 : 12)
    ..lineTo(-8.5, sport ? 26 : 24)
    ..quadraticBezierTo(0, sport ? 32 : 30, 8.5, sport ? 26 : 24)
    ..lineTo(7.5, sport ? 10 : 12)
    ..close();
  canvas.drawPath(rearFender, body);
  canvas.drawPath(rearFender, _strokePaint(width: 0.9));

  // Asiento negro alargado (firma visual Waze).
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, sport ? 4 : 6),
        width: sport ? 11 : 12,
        height: sport ? 28 : 30,
      ),
      const Radius.circular(5),
    ),
    seatPaint,
  );
  // Costura central del asiento.
  canvas.drawLine(
    Offset(0, sport ? -8 : -6),
    Offset(0, sport ? 16 : 18),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2,
  );

  // Depósito / carenado delantero.
  final tank = Path()
    ..moveTo(-8, sport ? -2 : 0)
    ..quadraticBezierTo(-9.5, -12, -6.5, sport ? -22 : -20)
    ..quadraticBezierTo(0, sport ? -28 : -26, 6.5, sport ? -22 : -20)
    ..quadraticBezierTo(9.5, -12, 8, sport ? -2 : 0)
    ..quadraticBezierTo(0, sport ? 4 : 5, -8, sport ? -2 : 0)
    ..close();
  canvas.drawPath(tank, body);
  canvas.drawPath(tank, _strokePaint(width: 0.9));

  // Brillo en el depósito.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(sport ? -2 : -2.5, sport ? -12 : -10),
      width: 4,
      height: 12,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.22),
  );

  // Manillar fino que sobresale (Waze).
  final barY = sport ? -18.0 : -16.0;
  canvas.drawLine(
    Offset(-15, barY),
    Offset(15, barY),
    Paint()
      ..color = const Color(0xFF1C1C1C)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round,
  );
  // Empuñaduras.
  canvas.drawCircle(Offset(-15, barY), 2.2, Paint()..color = const Color(0xFF111111));
  canvas.drawCircle(Offset(15, barY), 2.2, Paint()..color = const Color(0xFF111111));

  // Placa / faro frontal claro.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, sport ? -24 : -22),
        width: sport ? 7 : 8,
        height: sport ? 5 : 5.5,
      ),
      const Radius.circular(1.8),
    ),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -26),
        const Offset(0, -18),
        const [
          Color(0xFFFFFFFF),
          Color(0xFFE0E0E0),
        ],
      ),
  );

  if (sport) {
    // Cúpula corta.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -15), width: 9, height: 7),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF263238).withValues(alpha: 0.55),
    );
  }

  // Luz trasera mínima.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, sport ? 27 : 25), width: 5, height: 2.5),
      const Radius.circular(1),
    ),
    Paint()..color = const Color(0xFFE53935),
  );
}

void _paintScooter(Canvas canvas, Color color) {
  final body = _bodyPaint(color, halfWidth: 9);
  final tire = Paint()..color = const Color(0xFF111111);
  final seatPaint = Paint()..color = const Color(0xFF1A1A1A);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -26), width: 9, height: 6),
      const Radius.circular(3),
    ),
    tire,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 24), width: 10, height: 6),
      const Radius.circular(3),
    ),
    tire,
  );

  // Plataforma + escudo.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 6), width: 12, height: 26),
      const Radius.circular(4),
    ),
    body,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 6), width: 12, height: 26),
      const Radius.circular(4),
    ),
    _strokePaint(width: 0.9),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -12), width: 14, height: 16),
      const Radius.circular(5),
    ),
    body,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 8), width: 10, height: 16),
      const Radius.circular(4),
    ),
    seatPaint,
  );

  canvas.drawLine(
    const Offset(-13, -16),
    const Offset(13, -16),
    Paint()
      ..color = const Color(0xFF1C1C1C)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -22), width: 7, height: 4.5),
      const Radius.circular(1.5),
    ),
    Paint()..color = const Color(0xFFF5F5F5),
  );
}

void _paintWheels(
  Canvas canvas, {
  required double track,
  required double wheelbase,
  required double width,
  required double length,
  double yOffset = 0,
}) {
  final rubber = Paint()..color = const Color(0xFF212121);
  final hubs = [
    Offset(-track / 2, yOffset - wheelbase / 2),
    Offset(track / 2, yOffset - wheelbase / 2),
    Offset(-track / 2, yOffset + wheelbase / 2),
    Offset(track / 2, yOffset + wheelbase / 2),
  ];
  for (final c in hubs) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: width, height: length),
        const Radius.circular(2),
      ),
      rubber,
    );
  }
}
