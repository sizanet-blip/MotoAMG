import 'dart:convert';
import 'dart:math';

import 'package:moto_amg/core/constants/app_constants.dart';

/// Usuario único + correo sintético + clave de recuperación.
abstract final class UsernameAuth {
  static const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String normalize(String username) => username.trim().toLowerCase();

  static String authEmail(String username) {
    return '${normalize(username)}@${AppConstants.usernameAuthDomain}';
  }

  static bool isSyntheticEmail(String? email) {
    final value = email?.trim().toLowerCase() ?? '';
    return value.endsWith('@${AppConstants.usernameAuthDomain}');
  }

  static String? usernameFromEmail(String? email) {
    if (!isSyntheticEmail(email)) {
      return null;
    }
    return email!.split('@').first;
  }

  static String generateRecoveryKey() {
    final rng = Random.secure();
    String block() => List.generate(
      4,
      (_) => _recoveryAlphabet[rng.nextInt(_recoveryAlphabet.length)],
    ).join();
    return 'MA-${block()}-${block()}-${block()}-${block()}';
  }

  static String normalizeRecoveryKey(String input) {
    var raw = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // MA = MotoAMG; LM = prefijo legado (LocMotos).
    if (raw.startsWith('MA') || raw.startsWith('LM')) {
      raw = raw.substring(2);
    }
    if (raw.length != 16) {
      return input.trim().toUpperCase();
    }
    return 'MA-${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-${raw.substring(12, 16)}';
  }

  static String generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }
}
