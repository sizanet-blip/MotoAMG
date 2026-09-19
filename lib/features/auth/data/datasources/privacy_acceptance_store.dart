import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/constants/app_constants.dart';

/// Aceptación de privacidad por identidad (uid / email).
/// NO se borra al hacer logout: así Google no vuelve a pedirla cada vez.
class PrivacyAcceptanceStore {
  static const _boxName = 'motoamg_privacy_by_identity';

  Box<String>? _box;

  Future<Box<String>> _open() async {
    return _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<void> remember({
    required String uid,
    String? email,
    required String version,
    DateTime? at,
  }) async {
    if (uid.trim().isEmpty || version.trim().isEmpty) return;
    final box = await _open();
    final payload =
        '$version|${(at ?? DateTime.now()).toIso8601String()}';
    await box.put('uid:${uid.trim()}', payload);
    final mail = email?.trim().toLowerCase() ?? '';
    if (mail.isNotEmpty) {
      await box.put('email:$mail', payload);
    }
  }

  Future<({String version, DateTime? at})?> lookup({
    String? uid,
    String? email,
  }) async {
    final box = await _open();
    final uidKey = (uid ?? '').trim();
    if (uidKey.isNotEmpty) {
      final hit = _parse(box.get('uid:$uidKey'));
      if (hit != null) return hit;
    }
    final mail = (email ?? '').trim().toLowerCase();
    if (mail.isNotEmpty) {
      return _parse(box.get('email:$mail'));
    }
    return null;
  }

  /// Si ya aceptó la versión vigente, rellena el usuario.
  Future<T> applyIfAccepted<T extends Object>({
    required T user,
    required String uid,
    String? email,
    required T Function(String version, DateTime? at) withPrivacy,
  }) async {
    final hit = await lookup(uid: uid, email: email);
    if (hit == null) return user;
    if (hit.version.trim() != AppConstants.privacyPolicyVersion) {
      return user;
    }
    return withPrivacy(hit.version, hit.at);
  }

  ({String version, DateTime? at})? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    final version = parts.first.trim();
    if (version.isEmpty) return null;
    DateTime? at;
    if (parts.length > 1) {
      at = DateTime.tryParse(parts[1]);
    }
    return (version: version, at: at);
  }
}
