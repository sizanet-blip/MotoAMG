import 'dart:math' as math;

import 'package:flutter/material.dart';

class MotoMarker extends StatelessWidget {
  const MotoMarker({
    super.key,
    required this.name,
    required this.color,
    required this.isMe,
    this.heading = 0,
    this.distanceLabel,
    this.isStale = false,
  });

  final String name;
  final Color color;
  final bool isMe;
  final double heading;
  final String? distanceLabel;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final title = isMe ? '$name (tú)' : name;
    final angle = heading.isFinite && heading.abs() > 8
        ? (heading - 90) * math.pi / 180
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (isStale)
                  const Text(
                    'Sin señal',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC62828),
                    ),
                  )
                else if (distanceLabel != null)
                  Text(
                    distanceLabel!,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x42000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.two_wheeler,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
