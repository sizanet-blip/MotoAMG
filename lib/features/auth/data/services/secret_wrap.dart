import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Cifra un secreto con la contraseña del usuario (XOR + SHA-256 iterado).
///
/// No es AES; basta para que la clave de recuperación no quede en claro
/// y para detectar una contraseña incorrecta antes de ir a Firebase.
abstract final class SecretWrap {
  static const _iterations = 10000;

  static String wrap({
    required String secret,
    required String password,
    required String salt,
  }) {
    final payload = '$secret:${_checksum(secret)}';
    final bytes = utf8.encode(payload);
    final key = _deriveKey(password, salt, bytes.length);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i]);
    return base64Encode(out);
  }

  static String unwrap({
    required String wrapped,
    required String password,
    required String salt,
  }) {
    final encoded = base64Decode(wrapped);
    final key = _deriveKey(password, salt, encoded.length);
    final payload = utf8.decode(
      List<int>.generate(encoded.length, (i) => encoded[i] ^ key[i]),
    );
    final separator = payload.lastIndexOf(':');
    if (separator <= 0) {
      throw const FormatException('payload');
    }
    final secret = payload.substring(0, separator);
    final checksum = payload.substring(separator + 1);
    if (checksum != _checksum(secret)) {
      throw const FormatException('checksum');
    }
    return secret;
  }

  static String _checksum(String secret) {
    return sha256.convert(utf8.encode(secret)).toString().substring(0, 8);
  }

  static List<int> _deriveKey(String password, String salt, int length) {
    var digest = sha256.convert(utf8.encode('$salt::$password'));
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    final key = <int>[];
    var block = digest.bytes;
    var n = 0;
    while (key.length < length) {
      block = sha256.convert([...block, ...utf8.encode('$salt:$n')]).bytes;
      key.addAll(block);
      n++;
    }
    return key.sublist(0, length);
  }
}
