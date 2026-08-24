import 'dart:math';

import 'package:loc_motos/core/constants/app_constants.dart';

/// Genera códigos de grupo cortos y legibles (sin 0/O/1/I).
abstract final class CodeGenerator {
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String groupCode({int length = AppConstants.groupCodeLength}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }
}
